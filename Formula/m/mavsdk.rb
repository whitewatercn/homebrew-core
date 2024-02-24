class Mavsdk < Formula
  include Language::Python::Virtualenv

  desc "API and library for MAVLink compatible systems written in C++17"
  homepage "https://mavsdk.mavlink.io"
  url "https://github.com/mavlink/MAVSDK.git",
      tag:      "v2.3.0",
      revision: "f5e6945956c021c1d166f3047b195dbb020da43d"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    rebuild 1
    sha256 cellar: :any,                 arm64_sonoma:   "6ec681d8683288dd3b5dcc34e1697bb965a26f07808efcd5f5295de4c6fbc120"
    sha256 cellar: :any,                 arm64_ventura:  "5d9cbc00bdba6a838a0aae3c975d2fe175b8febda4d305fdd9869c9a21d89c70"
    sha256 cellar: :any,                 arm64_monterey: "9714b2e951b1f831d56b10ca2ec5d1aacec63b2418547dd39cc157e1a919cb94"
    sha256 cellar: :any,                 sonoma:         "92d294cc9906b8dbc7151c614a6fbc8ee3a6e0d71c08fe743b68a4ac0dc2184a"
    sha256 cellar: :any,                 ventura:        "64bb4a533fdd42e403e82975e6aef95c7f76348e27452e7ed24f025fa3b7cb79"
    sha256 cellar: :any,                 monterey:       "2514232ad28635f6d0d91d661569d449b5e4e4bf04e330be549f34ea0f484f7c"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "557ffe7e9cd5e41e681bcad2f05078461574793cd0e6f40116b9dd4e6f8ee7e3"
  end

  depends_on "cmake" => :build
  depends_on "python@3.12" => :build
  depends_on "abseil"
  depends_on "c-ares"
  depends_on "curl"
  depends_on "grpc"
  depends_on "jsoncpp"
  depends_on "openssl@3"
  depends_on "protobuf"
  depends_on "re2"
  depends_on "tinyxml2"

  uses_from_macos "zlib"

  on_macos do
    depends_on "llvm" if DevelopmentTools.clang_build_version <= 1100
  end

  fails_with :clang do
    build 1100
    cause <<-EOS
      Undefined symbols for architecture x86_64:
        "std::__1::__fs::filesystem::__status(std::__1::__fs::filesystem::path const&, std::__1::error_code*)"
    EOS
  end

  fails_with gcc: "5"

  # MAVLINK_GIT_HASH in https://github.com/mavlink/MAVSDK/blob/v#{version}/third_party/mavlink/CMakeLists.txt
  resource "mavlink" do
    url "https://github.com/mavlink/mavlink.git",
        revision: "9840105a275db1f48f9711d0fb861e8bf77a2245"
  end

  def install
    # Fix version being reported as `v#{version}-dirty`
    inreplace "CMakeLists.txt", "OUTPUT_VARIABLE VERSION_STR", "OUTPUT_VARIABLE VERSION_STR_IGNORED"

    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1100)

    resource("mavlink").stage do
      system "cmake", "-S", ".", "-B", "build",
                      "-DPython_EXECUTABLE=#{which("python3.12")}",
                      *std_cmake_args(install_prefix: libexec)
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end

    # Source build adapted from
    # https://mavsdk.mavlink.io/develop/en/contributing/build.html
    system "cmake", "-S", ".", "-B", "build",
                    "-DSUPERBUILD=OFF",
                    "-DBUILD_SHARED_LIBS=ON",
                    "-DBUILD_MAVSDK_SERVER=ON",
                    "-DBUILD_TESTS=OFF",
                    "-DVERSION_STR=v#{version}-#{tap.user}",
                    "-DCMAKE_PREFIX_PATH=#{libexec}",
                    "-DCMAKE_INSTALL_RPATH=#{rpath}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    # Force use of Clang on Mojave
    ENV.clang if OS.mac?

    (testpath/"test.cpp").write <<~EOS
      #include <iostream>
      #include <mavsdk/mavsdk.h>
      using namespace mavsdk;
      int main() {
          Mavsdk mavsdk{Mavsdk::Configuration{Mavsdk::ComponentType::GroundStation}};
          std::cout << mavsdk.version() << std::endl;
          return 0;
      }
    EOS
    system ENV.cxx, "-std=c++17", testpath/"test.cpp", "-o", "test",
                    "-I#{include}", "-L#{lib}", "-lmavsdk"
    assert_match "v#{version}-#{tap.user}", shell_output("./test").chomp

    assert_equal "Usage: #{bin}/mavsdk_server [Options] [Connection URL]",
                 shell_output("#{bin}/mavsdk_server --help").split("\n").first
  end
end
