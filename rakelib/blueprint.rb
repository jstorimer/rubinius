Daedalus.blueprint do |i|
  gcc = i.gcc!(Rubinius::BUILD_CONFIG[:cc],
               Rubinius::BUILD_CONFIG[:cxx],
               Rubinius::BUILD_CONFIG[:ldshared],
               Rubinius::BUILD_CONFIG[:ldsharedxx])

  # First define all flags that all code needs to be build with.

  # -fno-omit-frame-pointer is needed to get a backtrace on FreeBSD.
  # It is enabled by default on OS X, on the other hand, not on Linux.
  # To use same build flags across platforms, it is added explicitly.
  gcc.cflags << "-pipe -Wall -fno-omit-frame-pointer"

  # Due to a Clang bug (http://llvm.org/bugs/show_bug.cgi?id=9825),
  # -mno-omit-leaf-frame-pointer is needed for Clang on Linux.
  # On other combinations of platform and compiler, this flag is implicitly
  # assumed from -fno-omit-frame-pointer. To use same build flags across
  # platforms, -mno-omit-leaf-frame-pointer is added explicitly.
  gcc.cflags << "-mno-omit-leaf-frame-pointer" if Rubinius::BUILD_CONFIG[:cc] == "clang"

  # We don't need RTTI information, so disable it. This makes it possible
  # to link Rubinius to an LLVM build with RTTI disabled. We also enable
  # visibility-inlines-hidden for slightly smaller code size and prevents
  # warnings when LLVM is also built with this flag.
  gcc.cxxflags << "-fno-rtti -fvisibility-inlines-hidden"

  gcc.cflags << Rubinius::BUILD_CONFIG[:system_cflags]
  gcc.cflags << Rubinius::BUILD_CONFIG[:user_cflags]
  gcc.cxxflags << Rubinius::BUILD_CONFIG[:system_cxxflags]
  gcc.cxxflags << Rubinius::BUILD_CONFIG[:user_cxxflags]

  if ENV['DEV']
    gcc.cflags << "-O0"
    gcc.mtime_only = true
  else
    gcc.cflags << "-O2"
  end

  if ENV['POKE']
    gcc.mtime_only = true
  end

  # This is necessary for the gcc sync prims to fully work
  if Rubinius::BUILD_CONFIG[:x86_32]
    gcc.cflags << "-march=i686"
  end

  Rubinius::BUILD_CONFIG[:defines].each do |flag|
    gcc.cflags << "-D#{flag}"
  end

  gcc.ldflags << "-lstdc++" << "-lm"

  Rubinius::BUILD_CONFIG[:lib_dirs].each do |path|
    gcc.ldflags << "-L#{path}" if File.exists? path
  end

  make = Rubinius::BUILD_CONFIG[:make]

  if RUBY_PLATFORM =~ /bsd/ and
      Rubinius::BUILD_CONFIG[:defines].include?('HAS_EXECINFO')
    gcc.ldflags << "-lexecinfo"
  end

  gcc.ldflags << Rubinius::BUILD_CONFIG[:system_ldflags]
  gcc.ldflags << Rubinius::BUILD_CONFIG[:user_ldflags]

  # Files
  subdirs = %w[ builtin capi util instruments gc llvm missing ].map do |x|
    "vm/#{x}/*.{cpp,c}"
  end

  files = i.source_files "vm/*.{cpp,c}", *subdirs

  perl = Rubinius::BUILD_CONFIG[:build_perl] || "perl"

  # Libraries
  ltm = i.external_lib "vendor/libtommath" do |l|
    l.cflags = gcc.cflags + ["-Ivendor/libtommath"]
    l.objects = [l.file("libtommath.a")]
    l.to_build do |x|
      x.command make
    end
  end
  gcc.add_library ltm
  files << ltm

  oniguruma = i.library_group "vendor/oniguruma" do |g|
    g.depends_on "config.h", "configure"

    gcc.cflags << "-Ivendor/oniguruma"
    g.cflags = gcc.cflags + ["-DHAVE_CONFIG_H", "-I.", "-I../../vm/capi/19/include"]

    g.static_library "libonig" do |l|
      l.source_files "*.c", "enc/*.c"
    end

    g.shared_library "enc/trans/big5"
    g.shared_library "enc/trans/chinese"
    g.shared_library "enc/trans/emoji"
    g.shared_library "enc/trans/emoji_iso2022_kddi"
    g.shared_library "enc/trans/emoji_sjis_docomo"
    g.shared_library "enc/trans/emoji_sjis_kddi"
    g.shared_library "enc/trans/emoji_sjis_softbank"
    g.shared_library "enc/trans/escape"
    g.shared_library "enc/trans/gb18030"
    g.shared_library "enc/trans/gbk"
    g.shared_library "enc/trans/iso2022"
    g.shared_library "enc/trans/japanese"
    g.shared_library "enc/trans/japanese_euc"
    g.shared_library "enc/trans/japanese_sjis"
    g.shared_library "enc/trans/korean"
    g.shared_library "enc/trans/newline"
    g.shared_library "enc/trans/single_byte"
    g.shared_library "enc/trans/utf8_mac"
    g.shared_library "enc/trans/utf_16_32"
  end
  files << oniguruma

  gdtoa = i.external_lib "vendor/libgdtoa" do |l|
    l.cflags = gcc.cflags + ["-Ivendor/libgdtoa"]
    l.objects = [l.file("libgdtoa.a")]
    l.to_build do |x|
      x.command make
    end
  end
  gcc.add_library gdtoa
  files << gdtoa

  ffi = i.external_lib "vendor/libffi" do |l|
    l.cflags = gcc.cflags + ["-Ivendor/libffi/include"]
    l.objects = [l.file(".libs/libffi.a")]
    l.to_build do |x|
      x.command "sh -c './configure --disable-builddir'" unless File.exists?("Makefile")
      x.command make
    end
  end
  gcc.add_library ffi
  files << ffi

  udis = i.external_lib "vendor/udis86" do |l|
    l.cflags = gcc.cflags + ["-Ivendor/udis86"]
    l.objects = [l.file("libudis86/.libs/libudis86.a")]
    l.to_build do |x|
      unless File.exists?("Makefile") and File.exists?("libudis86/Makefile")
        x.command "sh -c ./configure"
      end
      x.command make
    end
  end
  gcc.add_library udis
  files << udis

  if Rubinius::BUILD_CONFIG[:vendor_zlib]
    zlib = i.external_lib "vendor/zlib" do |l|
      l.cflags = gcc.cflags + ["-Ivendor/zlib"]
      l.objects = []
      l.to_build do |x|
        unless File.exists?("Makefile") and File.exists?("zconf.h")
          x.command "sh -c ./configure"
        end

        if Rubinius::BUILD_CONFIG[:windows]
          x.command "make -f win32/Makefile.gcc"
        else
          x.command make
        end
      end
    end
    gcc.add_library zlib
    files << zlib
  end

  if Rubinius::BUILD_CONFIG[:windows]
    winp = i.external_lib "vendor/winpthreads" do |l|
      l.cflags = gcc.cflags + ["-Ivendor/winpthreads/include"]
      l.objects = [l.file("libpthread.a")]
      l.to_build do |x|
        x.command "sh -c ./configure" unless File.exists?("Makefile")
        x.command make
      end
    end

    gcc.add_library winp

    files << winp
  end

  case Rubinius::BUILD_CONFIG[:llvm]
  when :prebuilt, :svn
    llvm = i.external_lib "vendor/llvm" do |l|
      l.cflags = gcc.cflags + ["-Ivendor/llvm/include"]
      l.objects = []
    end

    gcc.add_library llvm
  end

  case Rubinius::BUILD_CONFIG[:llvm]
  when :config, :prebuilt, :svn
    conf = Rubinius::BUILD_CONFIG[:llvm_configure]
    flags = `#{conf} --cflags`.strip.split(/\s+/)
    flags.delete_if { |x| x.index("-O") == 0 }
    flags.delete_if { |x| x =~ /-D__STDC/ }
    flags.delete_if { |x| x == "-DNDEBUG" }
    flags.delete_if { |x| x == "-fomit-frame-pointer" }
    flags.delete_if { |x| x == "-pedantic" }
    flags.delete_if { |x| x == "-W" }
    flags.delete_if { |x| x == "-Wextra" }

    flags << "-DENABLE_LLVM"

    ldflags = `#{conf} --ldflags`.strip.split(/\s+/)
    objects = `#{conf} --libfiles`.strip.split(/\s+/)

    if Rubinius::BUILD_CONFIG[:windows]
      ldflags = ldflags.sub(%r[-L/([a-zA-Z])/], '-L\1:/')

      objects.select do |f|
        f.sub!(%r[^/([a-zA-Z])/], '\1:/')
        File.file? f
      end
    end

    gcc.cflags.concat flags
    gcc.ldflags.concat ldflags
    gcc.ldflags.concat objects
  when :no
    # nothing, not using LLVM
  else
    STDERR.puts "Unsupported LLVM configuration: #{Rubinius::BUILD_CONFIG[:llvm]}"
    raise "get out"
  end


  Rubinius::BUILD_CONFIG[:include_dirs].each do |path|
    gcc.cflags << "-I#{path} " if File.exists? path
  end

  # Add these flags after building the libraries
  gcc.cflags << "-Ivm -Ivm/test/cxxtest -I. "

  gcc.cflags << "-Wno-unused-function"
  gcc.cflags << "-g -Werror"
  gcc.cflags << "-DRBX_PROFILER"
  gcc.cflags << "-D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS"
  gcc.cflags << "-D_LARGEFILE_SOURCE"
  gcc.cflags << "-D_FILE_OFFSET_BITS=64"

  cli = files.dup
  cli << i.source_file("vm/drivers/cli.cpp")

  exe = RUBY_PLATFORM =~ /mingw|mswin/ ? 'vm/vm.exe' : 'vm/vm'
  i.program exe, *cli

  test_files = files.dup
  test_files << i.source_file("vm/test/runner.cpp") { |f|
    tests = Dir["vm/test/**/test_*.hpp"].sort

    f.depends_on tests

    f.autogenerate do |x|
      x.command("#{perl} vm/test/cxxtest/cxxtestgen.pl --error-printer --have-eh " +
        "--abort-on-fail -include=string.h -include=stdlib.h " +
        "-include=vm/test/test_setup.h -o vm/test/runner.cpp " +
        tests.join(' '))
    end
  }

  i.program "vm/test/runner", *test_files
end
