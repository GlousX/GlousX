#!/bin/bash

PM_WORKERS="auto"

while getopts "t:" OPTION 2> /dev/null; do
	case ${OPTION} in
		t)
			PM_WORKERS="$OPTARG"
			;;
	esac
done

#Run-the-server tests
DATA_DIR="$(pwd)/test_data"
PLUGINS_DIR="$DATA_DIR/plugins"

rm -rf "$DATA_DIR"
rm GlousX.phar 2> /dev/null
mkdir "$DATA_DIR"
mkdir "$PLUGINS_DIR"

phpenv config-rm xdebug.ini
echo | pecl install channel://pecl.php.net/yaml-2.1.0
git clone https://github.com/pmmp/pthreads.git
cd pthreads
git checkout b81ab29df58fa0fb239a9d5ca1c2380a0d087feb
phpize
./configure
make
make install
cd ..
echo "extension=pthreads.so" >> ~/.phpenv/versions/$(phpenv version-name)/etc/php.ini
composer self-update --2
cd ../../..
composer make-server --ignore-platform-req=*

if [ -f GlousX.phar ]; then
	echo Server phar created successfully.
else
	echo Server phar was not created!
	exit 1
fi

cp -r tests/plugins/TesterPlugin "$PLUGINS_DIR"
echo -e "stop\n" | php GlousX.phar --no-wizard --disable-ansi --disable-readline --debug.level=2 --data="$DATA_DIR" --plugins="$PLUGINS_DIR" --anonymous-statistics.enabled=0 --settings.async-workers="$PM_WORKERS" --settings.enable-dev-builds=1

output=$(grep '\[TesterPlugin\]' "$DATA_DIR/server.log")
if [ "$output" == "" ]; then
	echo TesterPlugin failed to run tests, check the logs
	exit 1
fi

result=$(echo "$output" | grep 'Finished' | grep -v 'PASS')
if [ "$result" != "" ]; then
	echo "$result"
	echo Some tests did not complete successfully, changing build status to failed
	exit 1
elif [ $(grep -c "ERROR\|CRITICAL\|EMERGENCY" "$DATA_DIR/server.log") -ne 0 ]; then
	echo Server log contains error messages, changing build status to failed
	exit 1
else
	echo All tests passed
fi
