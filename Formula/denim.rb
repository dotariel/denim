# This file is updated automatically by the release workflow.
class Denim < Formula
  desc "Persistent BlueJeans, Zoom, Slack huddle and Hangouts room opener"
  homepage "https://github.com/esumerfd/denim"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.11/denim_darwin_arm64.tar.gz"
      sha256 "fe5779ef34e57000c7673da7b5617c6acc49f31eef3e87190b9eccf3efe0df01"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.11/denim_darwin_amd64.tar.gz"
      sha256 "dad2a6f7339cc18347c25168274060d27e631f7e3b624447b56c5daf04ff3d7c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.11/denim_linux_arm64.tar.gz"
      sha256 "a4fe93c314774295ff7df61da70a0dcaa0313f1977c14dc2919fae3fa73de936"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.11/denim_linux_amd64.tar.gz"
      sha256 "7135238146325b6d01fb5aedd1b5aa4d69f5fc6ebe1cac5185f6776bcf0055d0"
    end
  end

  def install
    bin.install "denim"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/denim version")
  end
end
