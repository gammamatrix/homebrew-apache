require "formula"

class Httpd22 < Formula
  homepage "https://httpd.apache.org/"
  url "https://archive.apache.org/dist/httpd/httpd-2.2.27.tar.bz2"
  sha1 "fd4bf18dd1b3e0d9be9e85ff7e033b2eb8aa4976"

  conflicts_with "httpd24", :because => "different versions of the same software"

  skip_clean :la

  option "with-brewed-apr", "Use Homebrew's apr and apr-util instead of the bundled versions"
  option "with-brewed-openssl", "Use Homebrew's SSL instead of the system version"
  option "with-brewed-zlib", "Use Homebrew's zlib instead of the system version"
  option "with-ldap", "Include support for LDAP"
  option "with-privileged-ports", "Use the default ports 80 and 443 (which require root privileges), instead of 8080 and 8443"

  if build.with? "brewed-apr"
    depends_on "apr"
    depends_on "apr-util"
  end

  depends_on "pcre" => :optional
  depends_on "openssl" if build.with? "brewed-openssl"
  depends_on "homebrew/dupes/zlib" if build.with? "brewed-zlib"

  def install
    # point config files to opt_prefix instead of the version-specific prefix
    inreplace "Makefile.in",
      '#@@ServerRoot@@#$(prefix)#', '#@@ServerRoot@@'"##{opt_prefix}#"

    # install custom layout
    File.open('config.layout', 'w') { |f| f.write(httpd_layout) };

    args = %W[
      --enable-layout=Homebrew
      --enable-mods-shared=all
      --with-mpm=prefork
      --disable-unique-id
      --enable-ssl
      --enable-dav
      --enable-cache
      --enable-proxy
      --enable-logio
      --enable-deflate
      --enable-cgi
      --enable-cgid
      --enable-suexec
      --enable-rewrite
    ]

    if build.with? "brewed-openssl"
      openssl = Formula["openssl"].opt_prefix
      args << "--with-ssl=#{openssl}"
    else
      args << "--with-ssl=/usr"
    end

    if build.with? "privileged-ports"
      args << "--with-port=80"
      args << "--with-sslport=443"
    else
      args << "--with-port=8080"
      args << "--with-sslport=8443"
    end

    if build.with? "brewed-apr"
      apr = Formula["apr"].opt_prefix
      aprutil = Formula["apr-util"].opt_prefix

      args << "--with-apr=#{apr}"
      args << "--with-apr-util=#{aprutil}"
    else
      args << "--with-included-apr"
    end

    args << "--with-pcre=#{Formula['pcre'].opt_prefix}" if build.with? "pcre"

    if build.with? "brewed-zlib"
      args << "--with-z=#{Formula['zlib'].opt_prefix}"
    else
      args << "--with-z=#{MacOS.sdk_path}/usr"
    end

    if build.with? 'ldap'
      args << "--with-ldap"
      args << "--enable-ldap"
      args << "--enable-authnz-ldap"
    end

    system "./configure", *args

    system "make"
    system "make install"
    (var/"apache2/log").mkpath
    (var/"apache2/run").mkpath
    FileUtils.touch("#{var}/log/apache2/access_log") unless File.exists?("#{var}/log/apache2/access_log")
    FileUtils.touch("#{var}/log/apache2/error_log") unless File.exists?("#{var}/log/apache2/error_log")
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_prefix}/bin/httpd</string>
        <string>-D</string>
        <string>FOREGROUND</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  def httpd_layout
    return <<-EOS.undent
      <Layout Homebrew>
          prefix:        #{prefix}
          exec_prefix:   ${prefix}
          bindir:        ${exec_prefix}/bin
          sbindir:       ${exec_prefix}/bin
          libdir:        ${exec_prefix}/lib
          libexecdir:    ${exec_prefix}/libexec
          mandir:        #{man}
          sysconfdir:    #{etc}/apache2/2.2
          datadir:       #{var}/www
          installbuilddir: ${datadir}/build
          errordir:      ${datadir}/error
          iconsdir:      ${datadir}/icons
          htdocsdir:     ${datadir}/htdocs
          manualdir:     ${datadir}/manual
          cgidir:        #{var}/apache2/cgi-bin
          includedir:    ${prefix}/include/apache2
          localstatedir: #{var}/apache2
          runtimedir:    #{var}/run/apache2
          logfiledir:    #{var}/log/apache2
          proxycachedir: ${localstatedir}/proxy
      </Layout>
      EOS
  end

  test do
    system sbin/"httpd", "-v"
  end

  def caveats
    if build.with? "privileged-ports"
      <<-EOS.undent
      To load #{name} when --with-privileged-ports is used:
          sudo cp -v #{plist_path} /Library/LaunchDaemons
          sudo chown -v root:wheel /Library/LaunchDaemons/#{plist_path.basename}
          sudo chmod -v 644 /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      To reload #{name} after an upgrade when --with-privileged-ports is used:
          sudo launchctl unload /Library/LaunchDaemons/#{plist_path.basename}
          sudo launchctl load /Library/LaunchDaemons/#{plist_path.basename}

      If not using --with-privileged-ports, use the instructions below.
      EOS
    end
  end
end
