# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module contains copies of all of the unused Neuros databases.
# (We don't use them but the Neuros firmware expects them to be there
# and valid.)


package Neuros::UnusedDb;

use Exporter 'import';
@EXPORT = qw(@EmptyDBs);

use strict;
use warnings;
use English;


our @EmptyDBs = (['failedhisi/failedhisi.mdb', <<'EOF'],
M`$H``0````$``P```$H````D```````````````````````8`````````!P`
M``````-(:5-I````!U5N<W5C8V5S<V9U;````"0``P`@```````4```````E
M```````8`````#__```````@```````#4&QA>0````=$96QE=&4@0VQI<```
3```#17AI=```5T])1(```"4-"@``
EOF

                ['failedhisi/failedhisi.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````2@````````````````T*
EOF

                ['idedhisi/idedhisi.mdb' => <<'EOF'],
M`%,``0````$`"0```%,````C```````````````````````8`````````!P`
M``````-(:5-I````!DED96YT:69I960````N``0`)```````&@``````(```
M````'@``````)0``````(@`````__P``````*@```````TEN9F\````#4&QA
E>0````=$96QE=&4@0VQI<``````#17AI=```5T])1(```"4-"@``
EOF

                ['idedhisi/idedhisi.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````4P````````````````T*
EOF

                ['pcaudio/albums.mdb' => <<'EOF'],
M`"H```````$``0```"H````````````````````````````8````'0```",`
M``````1!;&)U;7,``&%U9&EO+FUD8@`````$06QB=6US``!73TE$@```)0T*
EOF

                ['pcaudio/albums.pai' => <<'EOF'],
2`18@`@````````````````T*
EOF

                ['pcaudio/albums.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````*@````````````````T*
EOF

                ['pcaudio/artist.mdb' => <<'EOF'],
M`"L```````$``0```"L````````````````````````````8````'0```",`
M``````1!<G1I<W0``&%U9&EO+FUD8@`````%07)T:7-T<P```%=/242````E
"#0H`
EOF

                ['pcaudio/artist.pai' => <<'EOF'],
2`18@`@````````````````T*
EOF

                ['pcaudio/artist.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````*P````````````````T*
EOF

                ['pcaudio/genre.mdb' => <<'EOF'],
M`"H```````$``0```"H````````````````````````````8````'0```",`
M``````1'96YR90```&%U9&EO+FUD8@`````$1V5N<F5S``!73TE$@```)0T*
EOF

                ['pcaudio/genre.pai' => <<'EOF'],
2`18@`@````````````````T*
EOF

                ['pcaudio/genre.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````*@````````````````T*
EOF

                ['pcaudio/pcaudio.mdb' => <<'EOF'],
M`+4``0````8`"0```+4```!W```````````````````````L`````````#,`
M````````.````#\```!&````3````%(```!7````70```&(```!H````;P`&
M4$,@3&EB<F%R>0````13;VYG<P`````&4&QA>6QI<W1S````<&QA>6QI<W0N
M;61B````!4%R=&ES=',```!A<G1I<W0N;61B````!$%L8G5M<P``86QB=6US
M+FUD8@````1'96YR97,``&=E;G)E+FUD8@`````&4F5C;W)D:6YG<P``<F5C
M;W)D:6YG<RYM9&(````\``4`)```````(`````"`````````)```````(P``
M````*@``````(0``````,P`````__P``````.````````TEN9F\````%1V5T
M($9I;&4````(061D(%1O($UY($UI>``````$1&5L971E`````T5X:70``%=/
(242````E#0H`
EOF

                ['pcaudio/pcaudio.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````M0````````````````T*
EOF

                ['pcaudio/playlist.mdb' => <<'EOF'],
M`"X```````$``0```"X````````````````````````````8````'P```"4`
M``````90;&%Y;&ES=',```!A=61I;RYM9&(`````!E!L87EL:7-T<P```%=/
6242````E@``A37D@36EX`````"4-"@``
EOF

                ['pcaudio/playlist.pai' => <<'EOF'],
M`18@`@`````````````````@````````````````````````````````````
E```````````````````````````````````````````````-"@``
EOF

                ['pcaudio/playlist.sai' => <<'EOF'],
M!1@9<0```````@``````````````````````+@`````````P````#@``````
%````#0H`
EOF

                ['pcaudio/recordings.mdb' => <<'EOF'],
M`"X```````$``0```"X````````````````````````````8````'P```"4`
M``````9296-O<F1I;F=S``!A=61I;RYM9&(`````!E)E8V]R9&EN9W,``%=/
(242````E#0H`
EOF

                ['pcaudio/recordings.pai' => <<'EOF'],
2`18@`@````````````````T*
EOF

                ['pcaudio/recordings.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````+@````````````````T*
EOF

                ['unidedhisi/unidedhisi.mdb' => <<'EOF'],
M`$P``0````$``P```$P````F```````````````````````8`````````!P`
M``````-(:5-I````"51O($)E($ED96YT:69I960````D``,`(```````%```
M````)0``````&``````__P``````(````````U!L87D````'1&5L971E($-L
7:7```````T5X:70``%=/242````E#0H`
EOF

                ['unidedhisi/unidedhisi.sai' => <<'EOF'],
J!1@9<0```````0``````````````````````3`````````````````T*
EOF

                ['audio/recordings.mdb' => <<'EOF'],
M`"X```````$``0```"X````````````````````````````8````'P```"4`
M``````9296-O<F1I;F=S``!A=61I;RYM9&(`````!E)E8V]R9&EN9W,``%=/
&242````E
EOF

                ['audio/recordings.pai' => <<'EOF'],
0`18@`@``````````````````
EOF

                ['audio/recordings.sai' => <<'EOF'],
H!1@9<0```````0``````````````````````+@``````````````````
EOF
               );

1;

