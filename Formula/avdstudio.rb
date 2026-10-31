class Avdstudio < Formula
  desc "Manage Android Virtual Devices from the terminal"
  homepage "https://github.com/mrcsxsiq/avd-studio"
  version "0.1.0"
  url "https://github.com/mrcsxsiq/avd-studio/releases/download/v#{version}/avdstudio-#{version}-macos-arm64.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on arch: :arm64
  depends_on :macos

  livecheck do
    url :url
    strategy :github_latest
  end

  def install
    bin.install "avdstudio"
  end

  def caveats
    <<~EOS
      Start with:  avdstudio doctor
      It checks your Android SDK and Java and tells you exactly what to install.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/avdstudio --version")
    assert_match "Usage", shell_output("#{bin}/avdstudio --help")
  end
end
