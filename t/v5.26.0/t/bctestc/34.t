sub eval_in_a_sub { my $todo = shift; eval $todo; } eval_in_a_sub("print q{ok}")
