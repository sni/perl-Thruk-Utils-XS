use ExtUtils::MakeMaker;
$Verbose = 1;
WriteMakefile(
    NAME => 'Thruk::Utils::XS::utils',
    SKIP => [qw(all static static_lib dynamic dynamic_lib)],
    clean => {'FILES' => 'libutils$(LIB_EXT)'},
);
sub MY::top_targets {
'
all :: static
pure_all :: static
static :: libutils$(LIB_EXT)
libutils$(LIB_EXT): $(O_FILES)
	$(AR) cr libutils$(LIB_EXT) $(O_FILES)
	$(RANLIB) libutils$(LIB_EXT)
';
}
