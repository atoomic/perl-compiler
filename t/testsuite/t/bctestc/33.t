sub c { caller(0) }  sub foo { package PQR; main->c() } print((foo())[0])
