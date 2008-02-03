#!/bin/sh

# test.sh - simple test script to check output of name lookup commands
#
# Copyright (C) 2007, 2008 Arthur de Jong
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 USA

# This script expects to be run in an environment where nss-ldapd
# is deployed with an LDAP server with the proper contents (nslcd running).
# FIXME: update the above description and provide actual LDIF file
# It's probably best to run this in an environment without nscd.

# note that nscd should not be running (breaks services test)

set -e

# check if LDAP is configured correctly
cfgfile="/etc/nss-ldapd.conf"
if [ -r "$cfgfile" ]
then
  :
else
  echo "test_nsscmds.sh: $cfgfile: not found"
  exit 77
fi

uri=`sed -n 's/^uri *//p' "$cfgfile" | head -n 1`
base="dc=test,dc=tld"

# try to fetch the base DN (fail with exit 77 to indicate problem)
ldapsearch -b "$base" -s base -x -H "$uri" > /dev/null 2>&1 || {
  echo "test_nsscmds.sh: LDAP server $uri not available for $base"
  exit 77
}

# basic check to see if nslcd is running
if [ -S /var/run/nslcd/socket ] && \
   [ -f /var/run/nslcd/nslcd.pid ] && \
   kill -s 0 `cat /var/run/nslcd/nslcd.pid` > /dev/null 2>&1
then
  :
else
  echo "test_nsscmds.sh: nslcd not running"
  exit 77
fi

# TODO: check if nscd is running

# TODO: check if /etc/nsswitch.conf is correct

echo "test_nsscmds.sh: using LDAP server $uri"

# the total number of errors
FAIL=0

check() {
  # the command to execute
  cmd="$1"
  # save the expected output
  expectfile=`mktemp -t expected.XXXXXX 2> /dev/null || tempfile -s .expected 2> /dev/null`
  cat > "$expectfile"
  # run the command
  echo 'test_nsscmds.sh: checking "'"$cmd"'"'
  actualfile=`mktemp -t actual.XXXXXX 2> /dev/null || tempfile -s .actual 2> /dev/null`
  eval "$cmd" > "$actualfile" 2>&1 || true
  # check for differences
  diff -Nauwi "$expectfile" "$actualfile" || FAIL=`expr $FAIL + 1`
  # remove temporary files
  rm "$expectfile" "$actualfile"
}

###########################################################################

echo "test_nsscmds.sh: testing aliases..."

# check all aliases
check "getent aliases|sort" << EOM
bar2:           foobar@example.com
bar:            foobar@example.com
foo:            bar@example.com
EOM

# get alias by name
check "getent aliases foo" << EOM
foo:            bar@example.com
EOM

# get alias by second name
check "getent aliases bar2" << EOM
bar2:           foobar@example.com
EOM

###########################################################################

echo "test_nsscmds.sh: testing ether..."

# get an entry by hostname
check "getent ethers testhost" << EOM
0:18:8a:54:1a:8e testhost
EOM

# get an entry by alias name
check "getent ethers testhostalias" << EOM
0:18:8a:54:1a:8e testhostalias
EOM

# get an entry by ethernet address
check "getent ethers 0:18:8a:54:1a:8b" << EOM
0:18:8a:54:1a:8b testhost2
EOM

# get entry by ip address
# this does not currently work, but maybe it should
#check "getent ethers 10.0.0.1" << EOM
#0:18:8a:54:1a:8e testhost
#EOM

# get all ethers (unsupported)
check "getent ethers" << EOM
Enumeration not supported on ethers
EOM

###########################################################################

echo "test_nsscmds.sh: testing group..."

check "getent group testgroup" << EOM
testgroup:*:6100:arthur,test
EOM

# this does not work because users is in /etc/group but it would
# be nice if libc supported this
#check "getent group users" << EOM
#users:*:100:arthur,test
#EOM

check "getent group 6100" << EOM
testgroup:*:6100:arthur,test
EOM

check "groups arthur | sed 's/^.*://'" << EOM
users testgroup testgroup2
EOM

check "getent group | egrep '^(testgroup|users):'" << EOM
users:x:100:
testgroup:*:6100:arthur,test
users:*:100:arthur,test
EOM

check "getent group | wc -l" << EOM
`grep -c : /etc/group | awk '{print $1 + 5}'`
EOM

check "getent group | grep ^largegroup" << EOM
largegroup:*:1005:akraskouskas,alat,ameisinger,bdevera,behrke,bmoldan,btempel,cjody,clouder,cmanno,dbye,dciviello,dfirpo,dgivliani,dgosser,emcquiddy,enastasi,fcunard,gcubbison,gdaub,gdreitzler,ghanauer,gpomerance,gsusoev,gtinnel,gvollrath,gzuhlke,hgalavis,hhaffey,hhydrick,hmachesky,hpaek,hpolk,hsweezer,htomlinson,hzagami,igurwell,ihashbarger,jyeater,kbradbury,khathway,kklavetter,lbuchtel,lgandee,lkhubba,lmauracher,lseehafer,lvittum,mblanchet,mbodley,mciaccia,mjuris,ndipanfilo,nfilipek,nfunchess,ngata,ngullett,nkraker,nriofrio,nroepke,nrybij,oclunes,oebrani,okveton,osaines,otrevor,pdossous,phaye,psowa,purquilla,rkoonz,rlatessa,rworkowski,sdebry,sgurski,showe,slaforge,tabdelal,testusr2,testusr3,tfalconeri,tpaa,uschweyen,utrezize,vchevalier,vdelnegro,vleyton,vmedici,vmigliori,vpender,vwaltmann,wbrettschneide,wselim,wvalcin,wworf,yautin,ykisak,zgingrich,znightingale,zwinterbottom
EOM

check "getent group largegroup" << EOM
largegroup:*:1005:akraskouskas,alat,ameisinger,bdevera,behrke,bmoldan,btempel,cjody,clouder,cmanno,dbye,dciviello,dfirpo,dgivliani,dgosser,emcquiddy,enastasi,fcunard,gcubbison,gdaub,gdreitzler,ghanauer,gpomerance,gsusoev,gtinnel,gvollrath,gzuhlke,hgalavis,hhaffey,hhydrick,hmachesky,hpaek,hpolk,hsweezer,htomlinson,hzagami,igurwell,ihashbarger,jyeater,kbradbury,khathway,kklavetter,lbuchtel,lgandee,lkhubba,lmauracher,lseehafer,lvittum,mblanchet,mbodley,mciaccia,mjuris,ndipanfilo,nfilipek,nfunchess,ngata,ngullett,nkraker,nriofrio,nroepke,nrybij,oclunes,oebrani,okveton,osaines,otrevor,pdossous,phaye,psowa,purquilla,rkoonz,rlatessa,rworkowski,sdebry,sgurski,showe,slaforge,tabdelal,testusr2,testusr3,tfalconeri,tpaa,uschweyen,utrezize,vchevalier,vdelnegro,vleyton,vmedici,vmigliori,vpender,vwaltmann,wbrettschneide,wselim,wvalcin,wworf,yautin,ykisak,zgingrich,znightingale,zwinterbottom
EOM

check "getent group | grep ^hugegroup" << EOM
hugegroup:*:1006:pbondroff,pwhitmire,ygockel,dloubier,uwalpole,vmaynard,pdech,iweibe,ffigert,bsibal,oahyou,rpitter,clouder,isplonskowski,critchie,akertzman,ilawbaugh,omasone,nkempon,hhagee,cnoriego,nagerton,jappleyard,apurdon,ptraweek,hdyner,ohearl,rnordby,tfalconeri,ideveyra,rguinane,ameisinger,nramones,cgaudette,cmellberg,ppedraja,dfollman,mlinardi,hfludd,broher,scocuzza,fnottage,wtruman,ofelcher,sstuemke,ddeguire,jmatty,cpalmios,ocrabbs,gschaumburg,lbuchtel,thelfritz,klitehiser,hkinderknecht,psundeen,lringuette,cspilis,gwaud,mferandez,bouten,hpolintan,zculp,cpinela,atollefsrud,lcremer,hmuscaro,rgramby,lschenkelberg,lgradilla,kfaure,fhain,nasmar,sgropper,zscammahorn,isteinlicht,kdevincent,jherkenratt,prowena,thynson,brodgerson,ekenady,ecelestin,bbeckfield,bhelverson,vtowell,obihl,kwinterling,ahandy,hschoepfer,hgalavis,tkhora,mcoch,sskone,pminnis,kmoesch,tschnepel,ekeuper,pbascom,tmcmickle,kcomparoni,showe,bpinedo,nwiker,slerew,tbattista,mjeon,tmurata,saycock,aesbensen,tsearle,gpomerance,hkippes,oshough,iogasawara,srees,gdaub,mvedder,igizzi,pvierthaler,tsowells,arosel,hbukovsky,nhija,ivanschaack,mground,zbuscaglia,lcocherell,aziernicki,nglathar,ccyganiewicz,hsabol,fhalon,hmateer,okveton,pfavolise,denriquez,leberhardt,kgarced,gparkersmith,lyoula,ewicks,wdagrella,dhammontree,nriofrio,pwetherwax,rbernhagen,tsablea,cbrechbill,opuglisi,svielle,zborgmeyer,redling,ncermeno,mcasida,lschollmeier,tfetherston,hcarrizal,ggillim,nmoren,fsapien,amckinney,isowder,gmackinder,wconces,mpilon,lspielvogel,pwashuk,nkubley,hschelb,ebeachem,ksollitto,guresti,sarndt,mhollings,mneubacher,jdodge,phalkett,wmailey,mmcchristian,pcornn,nvyhnal,ebusk,cpentreath,gfaire,ediga,mquigg,rlatessa,hsweezer,mfaeth,tmccaffity,rdubuisson,bbrenton,rramirez,gclapham,ckistenmacher,rlambertus,htilzer,wcreggett,mkibler,jroman,gearnshaw,nrybij,kmandolfo,draymundo,rfidel,tmarkus,iseipel,vwokwicz,kmisove,ppeper,mbravata,ikulbida,hrenart,ienglert,vbigalow,vpeairs,bjolly,owhitelow,ysnock,kottomaniello,ghelderman,ihoa,nhayer,dcaltabiano,wkhazaleh,mruppel,jskafec,jkimpton,ugreenberg,dsherard,lsobrino,kwidrick,tlana,oosterhouse,swoodie,eserrett,cnabzdyk,akraskouskas,jseen,umosser,afuchs,sherzberg,cmiramon,oscarpello,tlowers,tairth,cpluid,cmcanulty,ascovel,cfasone,pvirelli,cflenner,htomlinson,pahles,fsavela,bdaughenbaugh,dtornow,ptoenjes,tmysinger,ndesautels,ekalfas,clewicki,hzagami,fsymmonds,kshippy,gallanson,kalguire,dmahapatra,eathey,xlantey,cklem,smillian,llasher,hbetterman,kseisler,badair,eziebert,mdickinson,psabado,slaningham,estockwin,kmcardle,opeet,cdickes,lgadomski,btempel,veisenhardt,vnazzal,kmallach,ksparling,zneeb,kthede,cwank,psiroky,bmarlin,opizzuti,vpender,yduft,htsuha,bphou,opoch,bmoling,ilevian,okave,thoch,ihegener,cdegravelle,ktriblett,ggehrke,tsepulueda,kheadlon,dfirpo,wnunziata,ualway,fsunderland,osaber,mpizzaro,jwinterton,wconstantino,werrick,emcquiddy,spolmer,uflander,hliverman,mcontreras,cdrumm,egrago,fgoben,zanderlik,jeverton,mtanzi,psharits,adishaw,iherrarte,uvanmatre,rtole,dhindsman,tstalworth,hlichota,pwademan,rginer,mredd,rmcstay,vcrofton,ileaman,fwidhalm,tbagne,xeppley,hcafourek,svongal,mtintle,njordon,jsweezy,sjankauskas,rmandril,ueriks,fkeef,fburrough,istarring,mlinak,lnormand,cpaccione,tkelly,hwestermark,sestergard,ihanneman,vkrug,sdebry,tdonathan,nridinger,fthein,prepasky,kwirght,ehindbaugh,mcolehour,vbonder,pwutzke,bguthary,ewuitschick,rpinilla,tkeala,dscheurer,ycobetto,uslavinski,ihalford,kmarzili,fbielecki,kmcguire,ycostaneda,gapkin,dtuholski,dlanois,bswantak,lrandall,wottesen,kbrugal,carguellez,awhitt,ubenken,gcukaj,lkimel,fbeatrice,myokoyama,mfitzherbert,nbugtong,uazatyan,kcofrancesco,fagro,sscheiern,vemily,cweiss,nchrisman,yhenriques,gbitar,pdurando,csoomaroo,lseehafer,pgrybel,ngrowney,fvinal,ecolden,ascheno,kpenale,eaguire,teliades,charriman,mcampagnone,lhuggler,bwynes,nslaby,gportolese,hlemon,tguinnip,mgavet,cparee,cghianni,sgurski,kbattershell,vchevalier,tplatko,baigner,fcunard,rschkade,nlohmiller,rkraszewski,fcha,cmafnas,vrunyon,gkerens,cgaler,esproull,hmogush,tgindhart,lgandee,nforti,tabdelal,blovig,vpiraino,hhaffey,bmicklos,eklunder,kconkey,pbrentano,ewilles,areid,mlenning,pgreenier,hzinda,upater,svandewalle,kmedcaf,vnery,nphan,pbiggart,rdubs,sskyers,cswigert,rbrisby,mskeele,moser,mcashett,egospatrick,hmatonak,fparness,fsplinter,habby,fplayfair,gmings,snotari,sspagnuolo,kpannunzio,cjuntunen,svogler,mrydelek,moller,deshmon,skanjirathinga,imillin,ksiering,uholecek,kbarnthouse,vwisinger,vglidden,pheathcock,agarbett,jsegundo,uednilao,ibeto,lautovino,ejeppesen,ekurter,ilamberth,icoard,cbarlup,mbodley,hpimpare,cabare,mpark,tvehrs,psalesky,jlebouf,imuehl,dholdaway,mdecourcey,gconver,cbotdorf,lsous,hbickford,aferge,ajaquess,hpalmquist,rpastorin,wvalcin,iiffert,mcaram,lschnorbus,vsefcovic,ablackstock,mkofoed,fvascones,dmcgillen,agordner,rlosinger,ohatto,hrapisura,lmichaud,lcaudell,lpeagler,gchounlapane,tmorr,abortignon,esheehan,lcoulon,alienhard,dbarriball,dlablue,cbelardo,nousdahl,yvdberg,nerbach,vwaltmann,cmanno,iyorks,zmeeker,rgriffies,hbastidos,jquicksall,obeaufait,mstirn,ibuzo,ngullett,dblazejewski,lwedner,dlargo,nfunchess,bcolorado,gjankowiak,gdeblasio,uspittler,bmarszalek,astrunk,gcurnutt,fberra,zkutchera,pgiegerich,jscheitlin,ilacourse,cjody,hkohlmeyer,nlemma,ykimbel,adenicola,imicthell,ovibbert,cpencil,amccroskey,daubert,senrico,vfeigel,ibreitbart,nedgin,dgivliani,csever,bveeneman,jspohn,fsirianni,nevan,zwinterbottom,beon,imcbay,sgirsh,bharnois,amaslyn,achhor,oreiss,yolivier,iyorgey,ubynum,ngiesler,tvrooman,sstough,kfend,bwinterton,nlatchaw,gmassi,inarain,hcusta,ehathcock,pcaposole,wclokecloak,jholzmiller,ecordas,amcgraw,hloftis,rheinzmann,vtresch,vdolan,emanikowski,wdevenish,kbrevitz,umarbury,esonia,lpondexter,clapenta,lshilling,zvagt,garchambeault,lpitek,dbertels,rpikes,emehta,lmuehlberger,mdedon,obercier,kstachurski,glafontaine,dmarchizano,gtinnel,ubieniek,lseabold,pduitscher,kaanerud,kgremminger,ktuccio,epeterson,ljomes,rgoonez,rbloomstrand,lvaleriano,tharr,wstjean,hspiry,oport,kjoslyn,pphuaphes,cbourek,esthill,dsharr,lbove,sackles,dminozzi,klundsten,bfishbeck,nranck,udatu,jmartha,mmerriwether,dzurek,mmangiamele,mdyce,atonkin,tmalecki,rfauerbach,ojerabek,behrke,fberyman,istallcup,ktoni,owhelchel,jamber,lfarraj,wesguerra,uransford,mpellew,zhaulk,kpalka,ddigerolamo,tnaillon,wdovey,gmoen,nlinarez,rbillingsly,akomsthoeft,kmeester,skoegler,vlubic,nbuford,fgrashot,dpebbles,alat,saben,mpytko,nrysavy,hkarney,sbemo,gcummer,cbleimehl,dgosser,bscadden,emargulis,khovanesian,ckodish,meconomides,lcanestrini,hmiazga,tnitzel,ewismer,dnegri,dflore,mvanpelt,gdeyarmond,hchaviano,cfleurantin,pbeckerdite,jcaroll,nhelfinstine,ibyles,kpuebla,ycerasoli,smccaie,dtashjian,hbraim,ulanigan,jrees,ndrumgole,wmendell,mbeagley,jlunney,lpintor,mheilbrun,lparrish,uweyand,eorsten,gshrode,urosentrance,kmayoras,pdischinger,tgelen,bdadds,mallmand,fvallian,mfeil,ktuner,maustine,eyounglas,sbloise,usevera,qhanly,pdulac,ocalleo,lmauracher,vdesir,tsann,vtrumpp,ihimmelwright,dsteever,ochasten,ghann,mespinel,shaith,nnickel,gloebs,iroiger,edurick,bromano,upellam,hcowles,sbonnie,etunby,imensah,jsenavanh,slaudeman,ckerska,tcossa,jeuresti,sgunder,lfichtner,gdrilling,jmarugg,oalthouse,rtooker,mviverette,gbolay,wvermeulen,mvas,pthornberry,uschweyen,ikadar,faleo,cgalinol,yeven,afredin,amayorga,llarmore,tcrissinger,sgefroh,yfrymoyer,mdanos,nwescott,gmilian,bcoletta,bluellen,ghumbles,ugerpheide,oolivarez,mlaverde,bstrede,dlongbotham,farquette,mpanahon,phyer,cbartnick,mmattu,hriech,hstreitnatter,omalvaez,ithum,tmccamish,jjumalon,bdominga,yschmuff,venfort,mdoering,sbettridge,epoinelli,nspolar,xrahaim,lcavez,tpaa,srubenfield,lbassin,eparham,bdevera,ohoffert,tyounglas,dciullo,wlynch,hveader,hlynema,yautin,kmosko,eklein,pschrayter,nsiemonsma,wganther,dledenbach,imarungo,khartness,mmesidor,gsantella,vmedici,ashuey,nendicott,klurie,wleiva,fmilsaps,ohove,nciucci,pmineo,hvannette,zratti,lmcgeary,wbrill,eberkman,ctenny,ichewning,dgiacomazzi,mdimaio,lvanconant,gishii,nmccolm,hhysong,iambrosino,aponcedeleon,jbielicki,laksamit,agimm,limbrogno,ralspach,kbartolet,tcacal,erostad,hhartranft,mswogger,edrinkwater,tredfearn,cscullion,uhayakawa,bmadamba,hholyfield,pdauterman,gcervantez,lbanco,greiff,gvollrath,ctuzzo,rrasual,lsivic,ademosthenes,asemons,jglotzbecker,hbrehmer,jzych,jbjorkman,oconerly,erathert,mrizer,vrodick,btheim,dwittlinger,omcdaid,kepps,nlainhart,gfedewa,bgavagan,ihernan,mgayden,kolexa,gcobane,smullowney,ohedlund,pviviani,zfarler,cbrom,vstirman,pwohlenhaus,hwoodert,alamour,sbrabyn,joligee,hdoiel,kmuros,wenglander,asivley,ctetteh,tboxx,hlauchaire,fmarchi,rcheshier,oclunes,lmadruga,omatula,vbaldasaro,gcarlini,dhendon,krahman,amanganelli,rchevrette,jreigh,hbrandow,mvanbergen,nnamanworth,fverfaille,tmelland,purquilla,jvillaire,jknight,dasiedu,oebrani,nschmig,vwabasha,vburton,cdeckard,rfassinger,ninnella,hcintron,ebattee,wselim,obenallack,akravetz
EOM

check "getent group hugegroup" << EOM
hugegroup:*:1006:pbondroff,pwhitmire,ygockel,dloubier,uwalpole,vmaynard,pdech,iweibe,ffigert,bsibal,oahyou,rpitter,clouder,isplonskowski,critchie,akertzman,ilawbaugh,omasone,nkempon,hhagee,cnoriego,nagerton,jappleyard,apurdon,ptraweek,hdyner,ohearl,rnordby,tfalconeri,ideveyra,rguinane,ameisinger,nramones,cgaudette,cmellberg,ppedraja,dfollman,mlinardi,hfludd,broher,scocuzza,fnottage,wtruman,ofelcher,sstuemke,ddeguire,jmatty,cpalmios,ocrabbs,gschaumburg,lbuchtel,thelfritz,klitehiser,hkinderknecht,psundeen,lringuette,cspilis,gwaud,mferandez,bouten,hpolintan,zculp,cpinela,atollefsrud,lcremer,hmuscaro,rgramby,lschenkelberg,lgradilla,kfaure,fhain,nasmar,sgropper,zscammahorn,isteinlicht,kdevincent,jherkenratt,prowena,thynson,brodgerson,ekenady,ecelestin,bbeckfield,bhelverson,vtowell,obihl,kwinterling,ahandy,hschoepfer,hgalavis,tkhora,mcoch,sskone,pminnis,kmoesch,tschnepel,ekeuper,pbascom,tmcmickle,kcomparoni,showe,bpinedo,nwiker,slerew,tbattista,mjeon,tmurata,saycock,aesbensen,tsearle,gpomerance,hkippes,oshough,iogasawara,srees,gdaub,mvedder,igizzi,pvierthaler,tsowells,arosel,hbukovsky,nhija,ivanschaack,mground,zbuscaglia,lcocherell,aziernicki,nglathar,ccyganiewicz,hsabol,fhalon,hmateer,okveton,pfavolise,denriquez,leberhardt,kgarced,gparkersmith,lyoula,ewicks,wdagrella,dhammontree,nriofrio,pwetherwax,rbernhagen,tsablea,cbrechbill,opuglisi,svielle,zborgmeyer,redling,ncermeno,mcasida,lschollmeier,tfetherston,hcarrizal,ggillim,nmoren,fsapien,amckinney,isowder,gmackinder,wconces,mpilon,lspielvogel,pwashuk,nkubley,hschelb,ebeachem,ksollitto,guresti,sarndt,mhollings,mneubacher,jdodge,phalkett,wmailey,mmcchristian,pcornn,nvyhnal,ebusk,cpentreath,gfaire,ediga,mquigg,rlatessa,hsweezer,mfaeth,tmccaffity,rdubuisson,bbrenton,rramirez,gclapham,ckistenmacher,rlambertus,htilzer,wcreggett,mkibler,jroman,gearnshaw,nrybij,kmandolfo,draymundo,rfidel,tmarkus,iseipel,vwokwicz,kmisove,ppeper,mbravata,ikulbida,hrenart,ienglert,vbigalow,vpeairs,bjolly,owhitelow,ysnock,kottomaniello,ghelderman,ihoa,nhayer,dcaltabiano,wkhazaleh,mruppel,jskafec,jkimpton,ugreenberg,dsherard,lsobrino,kwidrick,tlana,oosterhouse,swoodie,eserrett,cnabzdyk,akraskouskas,jseen,umosser,afuchs,sherzberg,cmiramon,oscarpello,tlowers,tairth,cpluid,cmcanulty,ascovel,cfasone,pvirelli,cflenner,htomlinson,pahles,fsavela,bdaughenbaugh,dtornow,ptoenjes,tmysinger,ndesautels,ekalfas,clewicki,hzagami,fsymmonds,kshippy,gallanson,kalguire,dmahapatra,eathey,xlantey,cklem,smillian,llasher,hbetterman,kseisler,badair,eziebert,mdickinson,psabado,slaningham,estockwin,kmcardle,opeet,cdickes,lgadomski,btempel,veisenhardt,vnazzal,kmallach,ksparling,zneeb,kthede,cwank,psiroky,bmarlin,opizzuti,vpender,yduft,htsuha,bphou,opoch,bmoling,ilevian,okave,thoch,ihegener,cdegravelle,ktriblett,ggehrke,tsepulueda,kheadlon,dfirpo,wnunziata,ualway,fsunderland,osaber,mpizzaro,jwinterton,wconstantino,werrick,emcquiddy,spolmer,uflander,hliverman,mcontreras,cdrumm,egrago,fgoben,zanderlik,jeverton,mtanzi,psharits,adishaw,iherrarte,uvanmatre,rtole,dhindsman,tstalworth,hlichota,pwademan,rginer,mredd,rmcstay,vcrofton,ileaman,fwidhalm,tbagne,xeppley,hcafourek,svongal,mtintle,njordon,jsweezy,sjankauskas,rmandril,ueriks,fkeef,fburrough,istarring,mlinak,lnormand,cpaccione,tkelly,hwestermark,sestergard,ihanneman,vkrug,sdebry,tdonathan,nridinger,fthein,prepasky,kwirght,ehindbaugh,mcolehour,vbonder,pwutzke,bguthary,ewuitschick,rpinilla,tkeala,dscheurer,ycobetto,uslavinski,ihalford,kmarzili,fbielecki,kmcguire,ycostaneda,gapkin,dtuholski,dlanois,bswantak,lrandall,wottesen,kbrugal,carguellez,awhitt,ubenken,gcukaj,lkimel,fbeatrice,myokoyama,mfitzherbert,nbugtong,uazatyan,kcofrancesco,fagro,sscheiern,vemily,cweiss,nchrisman,yhenriques,gbitar,pdurando,csoomaroo,lseehafer,pgrybel,ngrowney,fvinal,ecolden,ascheno,kpenale,eaguire,teliades,charriman,mcampagnone,lhuggler,bwynes,nslaby,gportolese,hlemon,tguinnip,mgavet,cparee,cghianni,sgurski,kbattershell,vchevalier,tplatko,baigner,fcunard,rschkade,nlohmiller,rkraszewski,fcha,cmafnas,vrunyon,gkerens,cgaler,esproull,hmogush,tgindhart,lgandee,nforti,tabdelal,blovig,vpiraino,hhaffey,bmicklos,eklunder,kconkey,pbrentano,ewilles,areid,mlenning,pgreenier,hzinda,upater,svandewalle,kmedcaf,vnery,nphan,pbiggart,rdubs,sskyers,cswigert,rbrisby,mskeele,moser,mcashett,egospatrick,hmatonak,fparness,fsplinter,habby,fplayfair,gmings,snotari,sspagnuolo,kpannunzio,cjuntunen,svogler,mrydelek,moller,deshmon,skanjirathinga,imillin,ksiering,uholecek,kbarnthouse,vwisinger,vglidden,pheathcock,agarbett,jsegundo,uednilao,ibeto,lautovino,ejeppesen,ekurter,ilamberth,icoard,cbarlup,mbodley,hpimpare,cabare,mpark,tvehrs,psalesky,jlebouf,imuehl,dholdaway,mdecourcey,gconver,cbotdorf,lsous,hbickford,aferge,ajaquess,hpalmquist,rpastorin,wvalcin,iiffert,mcaram,lschnorbus,vsefcovic,ablackstock,mkofoed,fvascones,dmcgillen,agordner,rlosinger,ohatto,hrapisura,lmichaud,lcaudell,lpeagler,gchounlapane,tmorr,abortignon,esheehan,lcoulon,alienhard,dbarriball,dlablue,cbelardo,nousdahl,yvdberg,nerbach,vwaltmann,cmanno,iyorks,zmeeker,rgriffies,hbastidos,jquicksall,obeaufait,mstirn,ibuzo,ngullett,dblazejewski,lwedner,dlargo,nfunchess,bcolorado,gjankowiak,gdeblasio,uspittler,bmarszalek,astrunk,gcurnutt,fberra,zkutchera,pgiegerich,jscheitlin,ilacourse,cjody,hkohlmeyer,nlemma,ykimbel,adenicola,imicthell,ovibbert,cpencil,amccroskey,daubert,senrico,vfeigel,ibreitbart,nedgin,dgivliani,csever,bveeneman,jspohn,fsirianni,nevan,zwinterbottom,beon,imcbay,sgirsh,bharnois,amaslyn,achhor,oreiss,yolivier,iyorgey,ubynum,ngiesler,tvrooman,sstough,kfend,bwinterton,nlatchaw,gmassi,inarain,hcusta,ehathcock,pcaposole,wclokecloak,jholzmiller,ecordas,amcgraw,hloftis,rheinzmann,vtresch,vdolan,emanikowski,wdevenish,kbrevitz,umarbury,esonia,lpondexter,clapenta,lshilling,zvagt,garchambeault,lpitek,dbertels,rpikes,emehta,lmuehlberger,mdedon,obercier,kstachurski,glafontaine,dmarchizano,gtinnel,ubieniek,lseabold,pduitscher,kaanerud,kgremminger,ktuccio,epeterson,ljomes,rgoonez,rbloomstrand,lvaleriano,tharr,wstjean,hspiry,oport,kjoslyn,pphuaphes,cbourek,esthill,dsharr,lbove,sackles,dminozzi,klundsten,bfishbeck,nranck,udatu,jmartha,mmerriwether,dzurek,mmangiamele,mdyce,atonkin,tmalecki,rfauerbach,ojerabek,behrke,fberyman,istallcup,ktoni,owhelchel,jamber,lfarraj,wesguerra,uransford,mpellew,zhaulk,kpalka,ddigerolamo,tnaillon,wdovey,gmoen,nlinarez,rbillingsly,akomsthoeft,kmeester,skoegler,vlubic,nbuford,fgrashot,dpebbles,alat,saben,mpytko,nrysavy,hkarney,sbemo,gcummer,cbleimehl,dgosser,bscadden,emargulis,khovanesian,ckodish,meconomides,lcanestrini,hmiazga,tnitzel,ewismer,dnegri,dflore,mvanpelt,gdeyarmond,hchaviano,cfleurantin,pbeckerdite,jcaroll,nhelfinstine,ibyles,kpuebla,ycerasoli,smccaie,dtashjian,hbraim,ulanigan,jrees,ndrumgole,wmendell,mbeagley,jlunney,lpintor,mheilbrun,lparrish,uweyand,eorsten,gshrode,urosentrance,kmayoras,pdischinger,tgelen,bdadds,mallmand,fvallian,mfeil,ktuner,maustine,eyounglas,sbloise,usevera,qhanly,pdulac,ocalleo,lmauracher,vdesir,tsann,vtrumpp,ihimmelwright,dsteever,ochasten,ghann,mespinel,shaith,nnickel,gloebs,iroiger,edurick,bromano,upellam,hcowles,sbonnie,etunby,imensah,jsenavanh,slaudeman,ckerska,tcossa,jeuresti,sgunder,lfichtner,gdrilling,jmarugg,oalthouse,rtooker,mviverette,gbolay,wvermeulen,mvas,pthornberry,uschweyen,ikadar,faleo,cgalinol,yeven,afredin,amayorga,llarmore,tcrissinger,sgefroh,yfrymoyer,mdanos,nwescott,gmilian,bcoletta,bluellen,ghumbles,ugerpheide,oolivarez,mlaverde,bstrede,dlongbotham,farquette,mpanahon,phyer,cbartnick,mmattu,hriech,hstreitnatter,omalvaez,ithum,tmccamish,jjumalon,bdominga,yschmuff,venfort,mdoering,sbettridge,epoinelli,nspolar,xrahaim,lcavez,tpaa,srubenfield,lbassin,eparham,bdevera,ohoffert,tyounglas,dciullo,wlynch,hveader,hlynema,yautin,kmosko,eklein,pschrayter,nsiemonsma,wganther,dledenbach,imarungo,khartness,mmesidor,gsantella,vmedici,ashuey,nendicott,klurie,wleiva,fmilsaps,ohove,nciucci,pmineo,hvannette,zratti,lmcgeary,wbrill,eberkman,ctenny,ichewning,dgiacomazzi,mdimaio,lvanconant,gishii,nmccolm,hhysong,iambrosino,aponcedeleon,jbielicki,laksamit,agimm,limbrogno,ralspach,kbartolet,tcacal,erostad,hhartranft,mswogger,edrinkwater,tredfearn,cscullion,uhayakawa,bmadamba,hholyfield,pdauterman,gcervantez,lbanco,greiff,gvollrath,ctuzzo,rrasual,lsivic,ademosthenes,asemons,jglotzbecker,hbrehmer,jzych,jbjorkman,oconerly,erathert,mrizer,vrodick,btheim,dwittlinger,omcdaid,kepps,nlainhart,gfedewa,bgavagan,ihernan,mgayden,kolexa,gcobane,smullowney,ohedlund,pviviani,zfarler,cbrom,vstirman,pwohlenhaus,hwoodert,alamour,sbrabyn,joligee,hdoiel,kmuros,wenglander,asivley,ctetteh,tboxx,hlauchaire,fmarchi,rcheshier,oclunes,lmadruga,omatula,vbaldasaro,gcarlini,dhendon,krahman,amanganelli,rchevrette,jreigh,hbrandow,mvanbergen,nnamanworth,fverfaille,tmelland,purquilla,jvillaire,jknight,dasiedu,oebrani,nschmig,vwabasha,vburton,cdeckard,rfassinger,ninnella,hcintron,ebattee,wselim,obenallack,akravetz
EOM

###########################################################################

echo "test_nsscmds.sh: testing hosts..."

check "getent hosts testhost" << EOM
10.0.0.1        testhost testhostalias
EOM

check "getent hosts testhostalias" << EOM
10.0.0.1        testhost testhostalias
EOM

check "getent hosts 10.0.0.1" << EOM
10.0.0.1        testhost testhostalias
EOM

check "getent hosts | grep testhost" << EOM
10.0.0.1        testhost testhostalias
EOM

# dummy test for IPv6 envoronment
check "getent hosts ::1" << EOM
::1             ip6-localhost ip6-loopback
EOM

# TODO: add more tests for IPv6 support

###########################################################################

echo "test_nsscmds.sh: testing netgroup..."

# check netgroup lookup of test netgroup
check "getent netgroup tstnetgroup" << EOM
tstnetgroup          (aap, , ) (noot, , )
EOM

###########################################################################

echo "test_nsscmds.sh: testing networks..."

check "getent networks testnet" << EOM
testnet               10.0.0.0
EOM

check "getent networks 10.0.0.0" << EOM
testnet               10.0.0.0
EOM

check "getent networks | grep testnet" << EOM
testnet               10.0.0.0
EOM

###########################################################################

echo "test_nsscmds.sh: testing passwd..."

check "getent passwd ecolden" << EOM
ecolden:x:5972:1000:Estelle Colden:/home/ecolden:/bin/bash
EOM

check "getent passwd arthur" << EOM
arthur:x:1000:100:Arthur de Jong:/home/arthur:/bin/bash
EOM

check "getent passwd 4089" << EOM
jguzzetta:x:4089:1000:Josephine Guzzetta:/home/jguzzetta:/bin/bash
EOM

# count the number of passwd entries in the 4000-5999 range
check "getent passwd | grep -c ':x:[45][0-9][0-9][0-9]:'" << EOM
2000
EOM

###########################################################################

echo "test_nsscmds.sh: testing protocols..."

check "getent protocols protfoo" << EOM
protfoo               140 protfooalias
EOM

check "getent protocols protfooalias" << EOM
protfoo               140 protfooalias
EOM

check "getent protocols 140" << EOM
protfoo               140 protfooalias
EOM

check "getent protocols icmp" << EOM
icmp                  1 ICMP
EOM

check "getent protocols | grep protfoo" << EOM
protfoo               140 protfooalias
EOM

###########################################################################

echo "test_nsscmds.sh: testing rpc..."

check "getent rpc rpcfoo" << EOM
rpcfoo          160002  rpcfooalias
EOM

check "getent rpc rpcfooalias" << EOM
rpcfoo          160002  rpcfooalias
EOM

check "getent rpc 160002" << EOM
rpcfoo          160002  rpcfooalias
EOM

check "getent rpc | grep rpcfoo" << EOM
rpcfoo          160002  rpcfooalias
EOM

###########################################################################

echo "test_nsscmds.sh: testing services..."

check "getent services foosrv" << EOM
foosrv                15349/tcp
EOM

check "getent services foosrv/tcp" << EOM
foosrv                15349/tcp
EOM

check "getent services foosrv/udp" << EOM
EOM

check "getent services 15349/tcp" << EOM
foosrv                15349/tcp
EOM

check "getent services 15349/udp" << EOM
EOM

check "getent services barsrv" << EOM
barsrv                15350/tcp
EOM

check "getent services barsrv/tcp" << EOM
barsrv                15350/tcp
EOM

check "getent services barsrv/udp" << EOM
barsrv                15350/udp
EOM

check "getent services | egrep '(foo|bar)srv' | sort" << EOM
barsrv                15350/tcp
barsrv                15350/udp
foosrv                15349/tcp
EOM

check "getent services | wc -l" << EOM
`grep -c '^[^#].' /etc/services | awk '{print $1 + 3}'`
EOM

###########################################################################

echo "test_nsscmds.sh: testing shadow..."

# NOTE: the output of this should depend on whether we are root or not

check "getent shadow ecordas" << EOM
ecordas:*::::7:2::0
EOM

check "getent shadow arthur" << EOM
arthur:*::100:200:7:2::0
EOM

# check if the number of passwd entries matches the number of shadow entries
check "getent shadow | wc -l" << EOM
`getent passwd | wc -l`
EOM

# check if the names of users match between passwd and shadow
getent passwd | sed 's/:.*//' | sort | \
  check "getent shadow | sed 's/:.*//' | sort"

###########################################################################
# determine the result

if [ $FAIL -eq 0 ]
then
  echo "test_nsscmds.sh: all tests passed"
  exit 0
else
  echo "test_nsscmds.sh: $FAIL tests failed"
  exit 1
fi
