require 'formula'

class GlobusCaCerts < Formula
  homepage 'http://www.igtf.net/'
  url 'https://dist.eugridpma.info/distribution/igtf/current/igtf-policy-installation-bundle-1.55.tar.gz'
  sha1 'fe9e5b3844da36ca67d32c9bb9bf2b3b25bcf7e5'
  version '1.55'

  def install
    system "./configure", "--prefix=#{prefix}/etc/grid-security/certificates",
                          "--with-profile=classic"
    system "make", "install"
  end
end
