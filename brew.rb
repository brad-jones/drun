class Drun < Formula
    desc "A dartlang task runner."
    homepage "https://github.com/brad-jones/drun"
    url "https://github.com/brad-jones/drun/releases/download/v{{VERSION}}/drun-darwin-x64.tar.gz"
    version "{{VERSION}}"
    sha256 "{{HASH}}"

    def install
        bin.install "drun"
    end

    test do
        system "#{bin}/drun -v"
    end
end
