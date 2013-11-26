require 'formula'

class PythonGridftp < Formula
  homepage 'https://github.com/dsschult/python-gridftp'
  url 'https://github.com/dsschult/python-gridftp.git'
  version 'master'

  def install
    ENV.deparallelize
    system "python setup.py install --prefix=#{prefix}"
  end
end

