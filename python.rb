require 'formula'

class Python < Formula
  homepage 'http://www.python.org'
  url 'http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz'
  sha1 '8328d9f1d55574a287df384f4931a3942f03da64'

  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'homebrew/dupes/tcl-tk' if build.with? 'brewed-tk'

  resource 'setuptools' do
    url 'https://pypi.python.org/packages/source/s/setuptools/setuptools-1.4.2.tar.gz'
    sha1 '700ba918adef73b51a5356c3af44df58be7589bc'
  end

  resource 'pip' do
    url 'https://pypi.python.org/packages/source/p/pip/pip-1.4.1.tar.gz'
    sha1 '9766254c7909af6d04739b4a7732cc29e9a48cb0'
  end

  def site_packages_cellar
    prefix/"lib/python2.7/site-packages"
  end

  # The HOMEBREW_PREFIX location of site-packages.
  def site_packages
     HOMEBREW_PREFIX/"lib/python2.7/site-packages"
  end

  def install
    # Install Python
    cflags = "CFLAGS=-I#{HOMEBREW_PREFIX}/include"
    ldflags = "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib"
    if build.with? 'sqlite'
      cflags += " -I#{Formula.factory('sqlite').opt_prefix}/include"
      ldflags += " -L#{Formula.factory('sqlite').opt_prefix}/lib"
    end

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--enable-shared",
                          "--enable-ipv6",
                          "--prefix=#{prefix}",
                          cflags,
                          ldflags
    system "make", "install"
    
    # Remove the site-packages that Python created in its Cellar.
    site_packages_cellar.rmtree
    # Create a site-packages in HOMEBREW_PREFIX/lib/python2.7/site-packages
    site_packages.mkpath
    # Symlink the prefix site-packages into the cellar.
    ln_s site_packages, site_packages_cellar
    
    python_bin = prefix/"bin/python"

    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONHOME'] = nil
    ENV['PYTHONPATH'] = nil
    if ENV['LD_LIBRARY_PATH'] == nil
        ENV['LD_LIBRARY_PATH'] = prefix/"lib"
    else
        ENV['LD_LIBRARY_PATH'] += prefix/"lib"
    end

    setup_args = [ "-s", "setup.py", "--no-user-cfg", "install", "--force", "--verbose",
                   "--install-scripts=#{bin}", "--install-lib=#{site_packages}" ]

    # Install setuptools
    resource('setuptools').stage { system python_bin, *setup_args }

    # Install pip
    resource('pip').stage { system python_bin, *setup_args }

    # And now we write the distutils.cfg
    cfg = prefix/"lib/python2.7/distutils/distutils.cfg"
    cfg.delete if cfg.exist?
    cfg.write <<-EOF.undent
      [global]
      verbose=1
      [install]
      force=1
      prefix=#{HOMEBREW_PREFIX}
    EOF
  end

  test do
    system "#{bin}/python2"
    system "#{bin}/pip"
  end
end

