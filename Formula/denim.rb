# This file is updated automatically by the release workflow.
class Denim < Formula
  desc "Persistent BlueJeans, Zoom, Slack huddle and Hangouts room opener"
  homepage "https://github.com/esumerfd/denim"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.12/denim_darwin_arm64.tar.gz"
      sha256 "041d554495b3bc1d20ecc7064aaf226eebaf88ab4d001787a94c4b585d071167"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.12/denim_darwin_amd64.tar.gz"
      sha256 "4c954bfdce519a45bf838eccc5f7f0ce585daafe03951f88ad728bc4138750b4"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.12/denim_linux_arm64.tar.gz"
      sha256 "4c0c5d87bde47fb01bb10611cf17c654a735fdc01203852a15e1d5e8c9747ad3"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.1.12/denim_linux_amd64.tar.gz"
      sha256 "7fd564dda8b295f4829e1a80ad20ff870454edac71af0725c7725dba5cfbed47"
    end
  end

  def install
    bin.install "denim"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/denim version")
  end
end
