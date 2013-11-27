require 'formula'

class GlobusToolkit < Formula
  homepage 'http://www.globus.org/toolkit/'
  url 'http://www.globus.org/ftppub/gt5/5.2/5.2.5/installers/src/gt5.2.5-all-source-installer.tar.gz'
  version '5.2.5'
  sha1 '2e39065e0c3970b660e081705915d45640d3c350'

  option 'gridftp-client', 'Only install the gridftp client'

  depends_on 'libtool' => :recommended

  def install
    # fix up the configure script so libraries actually go in lib
    # --libdir to ./configure is ignored for some reason
    inreplace "configure", 'libdir=\'${exec_prefix}/lib32\'', 'libdir=\'${exec_prefix}/lib\''
    inreplace "configure", 'libdir=\'${exec_prefix}/lib64\'', 'libdir=\'${exec_prefix}/lib\''

    ENV.deparallelize
    system "./configure", "--prefix=#{prefix}"
    if build.include? 'gridftp-client'
      system "make gpt globus-data-management-client"
    else
      system "make"
    end
    system "make install"
  end
  
  def caveats
    return "Please set GLOBUS_LOCATION="+HOMEBREW_PREFIX
  end
end
