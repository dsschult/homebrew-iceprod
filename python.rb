require 'formula'

class Python < Formula
  homepage 'http://www.python.org'
  url 'http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz'
  sha1 '8328d9f1d55574a287df384f4931a3942f03da64'

  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'homebrew/dupes/tcl-tk' if build.with? 'brewed-tk'

  resource 'setuptools' do
    url 'https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py'
    sha1 '2959f6eaa3fa29f6c06874a416e8e6876bce7910'
  end

  resource 'pip' do
    url 'https://raw.github.com/pypa/pip/master/contrib/get-pip.py'
    sha1 '967e525ff8ad5ecc0c73c777f6fe9b0eee10b447'
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
  end
  
  def post_install
    python_bin = bin/"python"

    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONHOME'] = nil
    ENV['PYTHONPATH'] = nil

    # Install setuptools
    resource('setuptools').stage { system python_bin, "ez_setup.py" }

    # Install pip
    resource('pip').stage { system python_bin, "get-pip.py", "-I" }

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
    if linked_keg.symlink?
      linked_keg.unlink
      keg = Keg.new(prefix)
      begin
        keg.link
      rescue Exception => e
        onoe "The `brew link` step did not complete successfully"
      end
    end
  end

  test do
    system "#{bin}/python2"
  end
end
