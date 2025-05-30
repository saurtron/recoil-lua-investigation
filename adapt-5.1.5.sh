#! /bin/bash
LORIG=lua-5.1.5
LDEST=lua-5.1.5-spring
LSPRING=../spring/rts/lib/lua

rm -rf $LDEST
cp -r $LORIG $LDEST

cd $LDEST

# report luaNaN
patch -p1 < ../patches/report_luanan.diff
# add checknumber_noassert to mathlib
patch -p1 < ../patches/add-checknumber-noassert.diff
patch -p1 < ../patches/add-checknumber-noassert-2.diff
# set global *_func for system calls
patch -p1 < ../patches/io-security.diff
# hooks locking
patch -p1 < ../patches/userstate-locks.diff
# fixes modf for sync
patch -p1 < ../patches/mathlib-fix-modf.diff
# remove setlocale code for sync
patch -p1 < ../patches/loslib-nuke-setlocale.diff
# optimization from newer lua version?
patch -p1 < ../patches/lzio-eoz-optimization.diff
# add g->*_func variables, and make system calls work only if they're defined
patch -p1 < ../patches/def-disable-system-functions.diff
patch -p1 < ../patches/def-disable-system-functions-2.diff
# luaV_tostring sync safety
patch -p1 < ../patches/luaV_tostring-safety.diff
# l_strcmp sync safety
patch -p1 < ../patches/l_strcmp-safety.diff
# custom number2fmt and number2str methods for sync safety
patch -p1 < ../patches/number2fmt-number2str.diff
# lua_fopen
patch -p1 < ../patches/liolib-add-lua_fopen.diff
patch -p1 < ../patches/liolib-add-lua_fopen-2.diff
# random changed for sync safety
patch -p1 < ../patches/mathlib-synced-random.diff
# add some consts to math module
patch -p1 < ../patches/mathlib-add-consts.diff
# backport luaB-pairs from newer lua
patch -p1 < ../patches/luaB-pairs-backport.diff
# custom os_clock using spring libraries
patch -p1 < ../patches/loslib-custom-os_clock.diff
# custom number2int and number2integer (for sync safety?)
patch -p1 < ../patches/number2int-number2integer.diff
# luaB_tostring sync safety
patch -p1 < ../patches/luaB_tostring-sync-safety.diff
# make float numbers 32 bit
patch -p1 < ../patches/luaconf-spring-double.diff
# nummod changes (for sync safety?)
patch -p1 < ../patches/mathlib-nummod.diff
# hash variants of string
patch -p1 < ../patches/calchash-hstrstring.diff

mkdir include
mv src/lauxlib.h include/lauxlib.h
mv src/luaconf.h include/luaconf.h
mv src/lua.h include/lua.h
mv src/lualib.h include/lualib.h
rm src/lua.c
rm src/luac.c
rm Makefile
rm src/Makefile
rm -rf test doc etc

# cast -> lua_cast
rpl "cast\(" "lua_cast(" src/*
rpl "ifndef cast" "ifndef lua_cast" src/llimits.h

# redefine PI and RADIANS_PER_DEGREE
rpl -F "#define PI (3.14159265358979323846)" "//SPRING #define PI 3.14159265358979323846" src/lmathlib.c
rpl -F "#define RADIANS_PER_DEGREE (PI/180.0)" "#define RADIANS_PER_DEGREE math::DEG_TO_RAD //SPRING(PI/180.0)" src/lmathlib.c

# custom VERSION string
rpl -F "\"Lua 5.1\"" "\"Lua 5.1 with Recoil-specific changes\"" include/lua.h

# make lua_toboolean return bool
rpl -F "LUA_API int             (lua_toboolean)" "LUA_API bool             (lua_toboolean)" include/lua.h
rpl -F "LUA_API int lua_toboolean" "LUA_API bool lua_toboolean" src/lapi.c

# registry -> lua_registry
rpl -w -F "registry" "lua_registry" src/* include/*

# math.h -> streflop_cond.h
sed -i "s/#include <math.h>/\/\/SPRING#include <math.h>\n#include \"streflop_cond.h\"/g" include/luaconf.h
sed -i "s/#include <math.h>/\/\/SPRING#include <math.h>\n#include \"streflop_cond.h\"/g" src/ltable.c
sed -i "s/#include <math.h>/\/\/SPRING#include <math.h>\n#include \"streflop_cond.h\"/g" src/lmathlib.c
sed -i "s/#include <math.h>/\/\/SPRING#include <math.h>\n#include \"streflop_cond.h\"/g" src/lapi.c

# luaconf.h changes
sed -i "s/#define LUA_INTEGER	ptrdiff_t/\/\/SPRING we must use the same size for 64 and 32 bit. 32 bit int should be enough\n#define LUA_INTEGER	int/g" include/luaconf.h
sed -i "s/#define LUA_IDSIZE	60/#define LUA_IDSIZE	200/g" include/luaconf.h

# undef some LUA_COMPAT stuff
sed -i "s/#define LUA_COMPAT_LSTR/\/\/SPRING\n#undef LUA_COMPAT_LSTR\n\/\/#define LUA_COMPAT_LSTR/g" include/luaconf.h
for A in VARARG MOD GFIND OPENLIB; do
	sed -i "s/#define LUA_COMPAT_$A/\/\/SPRING\n#undef LUA_COMPAT_$A/g" include/luaconf.h
done

# add math:: prefix
rpl -F "lua_pushnumber(L, PI);" "lua_pushnumber(L, math::PI);" src/lmathlib.c
rpl -w "floor" " math::floor" include/luaconf.h
rpl -w "pow" " math::pow" include/luaconf.h

for A in sqrt fabs sin sinh cos cosh tan tanh asin acos atan atan2 ceil floor fmod pow log log10 exp frexp ldexp; do
	rpl " ${A}\(" " math::${A}(" src/lmathlib.c;
done

# add headers
# streflop_cond.h and System/BranchPrediction.h to src/lauxlib.c
sed -i -e '/#include "lauxlib.h"/a\' -e '\n#include "streflop_cond.h" \/\/ SPRING\n#include "System/BranchPrediction.h" \/\/ Recoil' src/lauxlib.c
# lstate.h to src/liolib.c
sed -i -e '/#include "lualib.h"/a\' -e '#include "lstate.h" /* SPRING */' src/liolib.c
# System/FastMath.h to src/lmathlib.c
sed -i -e '/#include "streflop_cond.h"/a\' -e '#include "System/FastMath.h"' src/lmathlib.c
# lstate.h to src/loslib.c
sed -i -e '/#include "lualib.h"/a\' -e '#include "lstate.h" /* SPRING */' src/loslib.c
# <algorithm> and streflop_cond.h to src/lvm.c
sed -i -e '/#include <string.h>/a\' -e '\n\/\/SPRING\n#include <algorithm>\n#include "streflop_cond.h"' src/lvm.c
# leftover comment :D
sed -i -e '/#include <stddef.h>/a\' -e '\n\/\/SPRING' src/lmem.c

# remove empty lines spring changes
sed -i -e '/#include "lua.h"/{n;d}' src/lauxlib.c
sed -i -e '/#include "lua.h"/{n;d}' src/lmathlib.c
sed -i -e '/\} LG;"/{n;d}' src/lstate.c

# NO CHANGE (mostly spacing)
sed -i "s/#define lua_number2int(i,d).*((i)=(int)(d))/\t#define lua_number2int(i, d)        ((i) = (int)(d))/g" include/luaconf.h
sed -i "s/#define lua_number2integer(i,d).*((i)=(lua_Integer)(d))/\t#define lua_number2integer(i, d)    ((i) = (lua_Integer)(d))/g" include/luaconf.h
rpl -F "((a)+(b))" "((a) + (b))" include/luaconf.h
rpl -F "((a)-(b))" "((a) - (b))" include/luaconf.h
rpl -F "((a)*(b))" "((a) * (b))" include/luaconf.h
rpl -F "((a)/(b))" "((a) / (b))" include/luaconf.h
rpl -F "((a)==(b))" "((a) == (b))" include/luaconf.h
rpl -F "((a)<(b))" "((a) <  (b))" include/luaconf.h
rpl -F "((a)<=(b))" "((a) <= (b))" include/luaconf.h
rpl -F "( math::pow(a,b))" "(math::pow((a), (b)))" include/luaconf.h
rpl "\/\/ string may be dead" "/* string may be dead */" src/lstring.c
rpl "\/\/ not found" "/* not found */"  src/lstring.c
# old copyright
rpl -F "Copyright (C) 1994-2012 Lua.org, PUC-Rio." "Copyright (C) 1994-2008 Lua.org, PUC-Rio." COPYRIGHT

# move .c files to .cpp
for A in `ls src/*.c`; do mv $A ${A}pp; done

cd ..
diff -ru $LDEST $LSPRING

