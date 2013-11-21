require 'formula'

class Tornadorpc < Formula
  homepage 'https://github.com/joshmarshall/tornadorpc'
  url 'https://github.com/joshmarshall/tornadorpc.git'
  version 'master'

  def install
    ENV.deparallelize
    system "python setup.py install --prefix=#{prefix}"
  end
end

