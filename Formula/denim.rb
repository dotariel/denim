# This file is updated automatically by the release workflow.
class Denim < Formula
  desc "Persistent BlueJeans, Zoom, Slack huddle and Hangouts room opener"
  homepage "https://github.com/esumerfd/denim"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_darwin_arm64.tar.gz"
      sha256 "712c2821177184261f52accff8d9972ae002e6c7d770c1ebd44b37bb9b11eee4"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_darwin_amd64.tar.gz"
      sha256 "d18b74f36bc64e713bbd1a128924f1a1c14ba9a19e3c3849f1002c18ee73d0fa"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_linux_arm64.tar.gz"
      sha256 "1c85afa22363780ab912e290a00aa2cb936baf3cf3b3f3728984ce24a2bda251"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_linux_amd64.tar.gz"
      sha256 "eb59b25d0225534b0252c9a76914298370280adfa9b1a414f96ee75632e65c5f"
    end
  end

  def install
    bin.install "denim"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/denim version")
  end
end
