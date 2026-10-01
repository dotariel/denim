# This file is updated automatically by the release workflow.
class Denim < Formula
  desc "Persistent BlueJeans, Zoom, Slack huddle and Hangouts room opener"
  homepage "https://github.com/esumerfd/denim"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_darwin_arm64.tar.gz"
      sha256 "1e1ce870713e2bbc0c1bba29bbe013f803c8cef55ef57efa1557e1c19b7d7487"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_darwin_amd64.tar.gz"
      sha256 "7884fef41124acff5f2523cb5091ba1e57b0b4d860c3fb04190ee2d3daae49cd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_linux_arm64.tar.gz"
      sha256 "ace264c57319f61ea1447f43aa55f643f65edce18c0af5e09de8388debe96fc5"
    end
    on_intel do
      url "https://github.com/esumerfd/denim/releases/download/v0.2.0/denim_linux_amd64.tar.gz"
      sha256 "62efe12e08408f4c2757fc0485c1ba95339232d1fecdf0432cc76b2632ed15be"
    end
  end

  def install
    bin.install "denim"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/denim version")
  end
end
