#!/bin/env perl

our $myre;
BEGIN { $myre = qr{(\p{IsWord}+)} }

print qq{1..1\n};
print qq{ok\n} if ref $myre;

