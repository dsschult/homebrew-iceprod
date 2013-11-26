require 'formula'

class PyuvTornado < Formula
  homepage 'https://github.com/dsschult/pyuv_tornado'
  url 'https://github.com/dsschult/pyuv_tornado.git'
  version 'master'

  def install
    ENV.deparallelize
    system "python setup.py install --prefix=#{prefix}"
  end
end

