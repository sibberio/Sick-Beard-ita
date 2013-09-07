#! /bin/sh

### BEGIN INIT INFO
# Provides:          Sick Beard application instance
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts instance of Sick Beard
# Description:       starts instance of Sick Beard using start-stop-daemon
### END INIT INFO

############### EDIT ME ##################

PUBLIC_SHARE=`/sbin/getcfg SHARE_DEF defPublic -d Public -f /etc/config/def_share.info`
DOWNLOAD_SHARE=`/sbin/getcfg SHARE_DEF defDownload -d Qdownload -f /etc/config/def_share.info`

QPKG_NAME=SickBeard
QPKG_DIR=
PID_FILE=/var/run/sickbeard.pid
DAEMON=/opt/bin/python2.6
DAEMON_OPTS=" SickBeard.py -q"
RUN_AS=admin

check_python(){
	#python2.6 dependency checking
	 [ ! -x $DAEMON ] && /sbin/write_log "Failed to start SickBeard, No Python2.6 runtime is found. Please re-install Python2.6 ipkg." 1 && exit 1
}

check_sabnzbdplus(){
    #sabnzbdplus dependency checking
    SABNZBDPLUS_INSTALL_PATH=`/sbin/getcfg SABnzbdplus Install_Path -f /etc/config/qpkg.conf`
    if [ "${SABNZBDPLUS_INSTALL_PATH}" == "" ]; then
		SABNZBDPLUS_INSTALL_PATH=`/sbin/getcfg SABnzbd+ Install_Path -f /etc/config/qpkg.conf`
		if [ "${SABNZBDPLUS_INSTALL_PATH}" == "" ]; then		
	        /sbin/write_log "Failed to start SickBeard, SABnzbdplus is not found. Please install SABnzbdplus first." 1
    	    exit 1
		fi
	fi
}

# Determine BASE installation location according to smb.conf
find_base()
{
    BASE=
    publicdir=`/sbin/getcfg $PUBLIC_SHARE path -f /etc/config/smb.conf`
    if [ ! -z $publicdir ] && [ -d $publicdir ];then
      publicdirp1=`/bin/echo $publicdir | /bin/cut -d "/" -f 2`
      publicdirp2=`/bin/echo $publicdir | /bin/cut -d "/" -f 3`
      publicdirp3=`/bin/echo $publicdir | /bin/cut -d "/" -f 4`
      if [ ! -z $publicdirp1 ] && [ ! -z $publicdirp2 ] && [ ! -z $publicdirp3 ]; then
            [ -d "/${publicdirp1}/${publicdirp2}/${PUBLIC_SHARE}" ] && BASE="/${publicdirp1}/${publicdirp2}"
      fi
    fi

    # Determine BASE installation location by checking where the Public folder is.
    if [ -z $BASE ]; then
      for datadirtest in /share/HDA_DATA /share/HDB_DATA /share/HDC_DATA /share/HDD_DATA /share/MD0_DATA /share/MD1_DATA; do
            [ -d $datadirtest/Public ] && QPKG_BASE="$datadirtest"
      done
    fi
    if [ -z $BASE ] ; then
        echo "The Public share not found."
        exit 1
    fi

    QPKG_DIR=${BASE}/.qpkg/${QPKG_NAME}
}

find_base

create_req_dirs(){
	[ ! -d "/share/${DOWNLOAD_SHARE}" ] && _exit 1
	[ -d "/share/${DOWNLOAD_SHARE}/sickbeard" ] || /bin/mkdir "/share/${DOWNLOAD_SHARE}/sickbeard"
	/bin/chmod 777 /share/$DOWNLOAD_SHARE/sickbeard		
}

create_links(){
		[ -f /usr/bin/start-stop-daemon ] || ln -sf ${QPKG_DIR}/bin/start-stop-daemon /usr/bin/start-stop-daemon
}

inject_sb_startup_procedure() {
	[ -f /etc/init.d/sabnzbd.sh ] && [ ! "`grep "## added by sickbeard" /etc/init.d/sabnzbd.sh`" ] && awk '{gsub("/bin/sleep 5","/bin/sleep 5\n\n\t\t## added by sickbeard\n\t\tif [ \"`/sbin/getcfg SickBeard Install_Path -f /etc/config/qpkg.conf`\" != \"\" ] \\&\\& [ \"`/sbin/getcfg SickBeard Enable -f /etc/config/qpkg.conf`\" = \"TRUE\" ]; then\n\t\t\t/etc/init.d/sickbeard.sh restart\n\t\tfi");print}' /etc/init.d/sabnzbd.sh > /tmp/sabnzbd.sh

	if [ -f /tmp/sabnzbd.sh ]; then
		/bin/chmod +x /tmp/sabnzbd.sh; 
		/bin/mv /tmp/sabnzbd.sh /etc/init.d/sabnzbd.sh
	fi
}

config_sickbeard() {
	if [ -f $SABconfig ] && [ -f ${QPKG_DIR}/config.ini ]; then
		/sbin/setcfg SABnzbd sab_username `/sbin/getcfg misc username -f $SABconfig` -f ${QPKG_DIR}/config.ini
		/sbin/setcfg SABnzbd sab_password `/sbin/getcfg misc password -f $SABconfig` -f ${QPKG_DIR}/config.ini
		/sbin/setcfg SABnzbd sab_apikey `/sbin/getcfg misc api_key -f $SABconfig` -f ${QPKG_DIR}/config.ini
		
		/sbin/setcfg NZBMatrix nzbmatrix_username `/sbin/getcfg nzbmatrix username -f $SABconfig` -f ${QPKG_DIR}/config.ini
		/sbin/setcfg NZBMatrix nzbmatrix_apikey `/sbin/getcfg nzbmatrix apikey -f $SABconfig` -f ${QPKG_DIR}/config.ini
	fi
	if [ -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg ] && [ -f ${QPKG_DIR}/config.ini ]; then
		/sbin/setcfg SickBeard host `/sbin/getcfg General web_host -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		/sbin/setcfg SickBeard port `/sbin/getcfg General web_port -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		/sbin/setcfg SickBeard username `/sbin/getcfg General web_username -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
		/sbin/setcfg SickBeard password `/sbin/getcfg General web_password -f ${QPKG_DIR}/config.ini` -f ${QPKG_DIR}/autoProcessTV/autoProcessTV.cfg
	fi	
}

config_sabnzbdplus() {
	if [ -f $SABconfig ] && [ -f ${QPKG_DIR}/config.ini ]; then
		/sbin/setcfg misc script_dir "${QPKG_DIR}/autoProcessTV" -f $SABconfig
		/sbin/setcfg misc enable_tv_sorting 0 -f $SABconfig
		
		/sbin/setcfg [tv] script sabToSickBeard.py -f $SABconfig
		/sbin/setcfg [tv] dir TV -f $SABconfig
	fi
	
	inject_sb_startup_procedure
}

case "$1" in
  start)
	#Does /opt exist? if not check if it's optware that's installed or opkg, and start the package 
	if [ ! -d /opt/bin ]; then
		/bin/echo "/opt not found, enabling optware or opkg..."
		#if optware start optware
		[ -x /etc/init.d/Optware.sh ] && /etc/init.d/Optware.sh start
		#if opkg, start opkg
		[ -x /etc/init.d/opkg.sh ] && /etc/init.d/opkg.sh start
		/bin/sync
		sleep 2
	fi

	 #find out where sabnzbd.ini is 
	SABconfig=""
	#SAB < 0.6
	[ -f "$BASE/.qpkg/SABnzbdplus/root/.sabnzbd/sabnzbd.ini" ] && SABconfig="$BASE/.qpkg/SABnzbdplus/root/.sabnzbd/sabnzbd.ini"
	#SAB >= 0.6
	[ -f "$BASE/.qpkg/SABnzbdplus/Config/sabnzbd.ini" ] && SABconfig="$BASE/.qpkg/SABnzbdplus/Config/sabnzbd.ini"

	check_python
	check_sabnzbdplus

	echo "Starting $QPKG_NAME"
	if [ `/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f /etc/config/qpkg.conf` = UNKNOWN ]; then
		/sbin/setcfg ${QPKG_NAME} Enable TRUE -f /etc/config/qpkg.conf
	elif [ `/sbin/getcfg ${QPKG_NAME} Enable -u -d FALSE -f /etc/config/qpkg.conf` != TRUE ]; then
	    echo "${QPKG_NAME} is disabled."
	    exit 1
	fi

        #link python 2.6 to /usr/bin/python2.6 to fix sabtosickbeard.py processing
        /bin/ln -sf /opt/bin/python2.6 /usr/bin/python
		
	echo "updating Sickbeard"
	cd $QPKG_DIR && /opt/bin/git reset --hard HEAD && /opt/bin/git pull && cd - && /bin/sync

	create_links
	create_req_dirs
#19-02-2011 disabled this to prevent updating on every reboot, only on install
#	config_sickbeard
	config_sabnzbdplus
		
       /usr/bin/start-stop-daemon -d $QPKG_DIR -c $RUN_AS --start --background --pidfile $PID_FILE  --make-pidfile --exec $DAEMON -- $DAEMON_OPTS
       ;;
  stop)
	echo "Stopping $QPKG_NAME"
	for pid in $(/bin/pidof python2.6); do
		/bin/grep -q "SickBeard.py" /proc/$pid/cmdline && /bin/kill $pid
	done
	/bin/sleep 2
       ;;

  restart|force-reload)
       echo "Restarting $QPKG_NAME"
	$0 stop 
	$0 start
       ;;
  *)
       N=/etc/init.d/$QPKG_NAME
       echo "Usage: $N {start|stop|restart|force-reload}" >&2
       exit 1
       ;;
esac

exit 0
