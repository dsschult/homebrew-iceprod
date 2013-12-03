require 'formula'

class Python < Formula
  homepage 'http://www.python.org'
  url 'http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz'
  sha1 '8328d9f1d55574a287df384f4931a3942f03da64'

  option 'quicktest', 'Run `make quicktest` after the build (for devs; may fail)'
  option 'with-brewed-openssl', "Use Homebrew's openSSL"
  option 'with-brewed-tk', "Use Homebrew's Tk"

  depends_on 'pkg-config' => :build
  depends_on 'readline' => :recommended
  depends_on 'sqlite' => :recommended
  depends_on 'gdbm' => :optional
  depends_on 'openssl' if build.with? 'brewed-openssl'
  depends_on 'homebrew/dupes/tcl-tk' if build.with? 'brewed-tk'
  depends_on :x11 if build.with? 'brewed-tk' and Tab.for_name('tcl-tk').used_options.include?('with-x11')

  skip_clean 'bin/pip', 'bin/pip-2.7'
  skip_clean 'bin/easy_install', 'bin/easy_install-2.7'

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
    # Unset these so that installing pip and setuptools puts them where we want
    # and not into some other Python the user has installed.
    ENV['PYTHONHOME'] = nil
    ENV['PYTHONPATH'] = nil

    args = %W[
             --prefix=#{prefix}
             --enable-shared
             --enable-ipv6
           ]

    if superenv?
      distutils_fix_superenv(args)
    else
      distutils_fix_stdenv
    end
    
    # Allow sqlite3 module to load extensions: http://docs.python.org/library/sqlite3.html#f1
    inreplace("setup.py", 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', '') if build.with? 'sqlite'

    # Allow python modules to use ctypes.find_library to find homebrew's stuff
    # even if homebrew is not a /usr/local/lib. Try this with:
    # `brew install enchant && pip install pyenchant`
    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! 'DEFAULT_LIBRARY_FALLBACK = [', "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
    end
    
    # Set correct final prefix location
    inreplace "./Python/sysmodule.c" do |f|
      f.gsub! 'Py_GetPrefix()', "\"#{HOMEBREW_PREFIX}\""
      f.gsub! 'Py_GetExecPrefix()', "\"#{HOMEBREW_PREFIX}/bin\""
    end

    system "./configure", *args
    system "make"
    ENV.deparallelize # Installs must be serialized
    system "make", "install"
    system "make", "quicktest" if build.include? 'quicktest'

    # Post-install, fix up the site-packages so that user-installed Python
    # software survives minor updates, such as going from 2.7.0 to 2.7.1:
    
    # Remove the site-packages that Python created in its Cellar.
    site_packages_cellar.rmtree
    # Create a site-packages in HOMEBREW_PREFIX/lib/python2.7/site-packages
    site_packages.mkpath
    # Symlink the prefix site-packages into the cellar.
    ln_s site_packages, site_packages_cellar
    
    python_bin = prefix/"bin/python"
    if ENV['LD_LIBRARY_PATH'] == nil
        ENV['LD_LIBRARY_PATH'] = prefix/"lib"
    else
        ENV['LD_LIBRARY_PATH'] += prefix/"lib"
    end

    # Remove old setuptools installations that may still fly around and be
    # listed in the easy_install.pth. This can break setuptools build with
    # zipimport.ZipImportError: bad local file header
    # setuptools-0.9.5-py3.3.egg
    rm_rf Dir["#{site_packages}/setuptools*"]
    rm_rf Dir["#{site_packages}/distribute*"]

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

  def distutils_fix_superenv(args)
    # This is not for building python itself but to allow Python's build tools
    # (pip) to find brewed stuff when installing python packages.
    cflags = "CFLAGS=-I#{HOMEBREW_PREFIX}/include -I#{Formula.factory('sqlite').opt_prefix}/include"
    ldflags = "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib -L#{Formula.factory('sqlite').opt_prefix}/lib"
    if build.with? 'brewed-tk'
      cflags += " -I#{Formula.factory('tcl-tk').opt_prefix}/include"
      ldflags += " -L#{Formula.factory('tcl-tk').opt_prefix}/lib"
    end
    args << cflags
    args << ldflags
    # We want our readline! This is just to outsmart the detection code,
    # superenv handles that cc finds includes/libs!
    inreplace "setup.py",
              "do_readline = self.compiler.find_library_file(lib_dirs, 'readline')",
              "do_readline = '#{HOMEBREW_PREFIX}/opt/readline/lib/libhistory.so'"
  end

  def distutils_fix_stdenv()
    # Don't use optimizations other than "-Os" here, because Python's distutils
    # remembers (hint: `python3-config --cflags`) and reuses them for C
    # extensions which can break software (such as scipy 0.11 fails when
    # "-msse4" is present.)
    ENV.minimal_optimization

    # We need to enable warnings because the configure.in uses -Werror to detect
    # "whether gcc supports ParseTuple" (https://github.com/mxcl/homebrew/issues/12194)
    ENV.enable_warnings
    if ENV.compiler == :clang
      # http://docs.python.org/devguide/setup.html#id8 suggests to disable some Warnings.
      ENV.append_to_cflags '-Wno-unused-value'
      ENV.append_to_cflags '-Wno-empty-body'
      ENV.append_to_cflags '-Qunused-arguments'
    end
  end


  def caveats
    <<-EOS.undent
      Python demo
        #{HOMEBREW_PREFIX}/share/python/Extras

      Setuptools and Pip have been installed. To update them
        pip install --upgrade setuptools
        pip install --upgrade pip

      You can install Python packages with (the outdated easy_install or)
        `pip install <your_favorite_package>`

      They will install into the site-package directory
        #{site_packages}

      See: https://github.com/mxcl/homebrew/wiki/Homebrew-and-Python
    EOS
  end

  test do
    system "#{bin}/python", "-c", "import sqlite3"
    system "#{bin}/pip"
  end
end

