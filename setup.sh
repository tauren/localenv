#!/bin/bash
###
# TODO: Get System Password from User
###


# TODO: Does not work yet!
# Need to download localenv package from github and uncompress 


###
# Default values
exclusions="";
inclusions="";
just_update_bash=false;
skip_base=false;

# ID values
shared_remote="https://raw.githubusercontent.com/tauren/localenv/master/";
shared_local="/Volumes/localenv";
src_location="$shared_local";
bash_src_location="$src_location/bash.id";
tools_src_location="$src_location/tools";
bash_location="$HOME/.bash";
profile_file="$HOME/.bash_profile";

###
# Get Arguments
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo " "
      echo " "
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-e, --exclusions=STRING   comma delimited string of items to exclude from the installation"
      echo "-i, --inclusions=STRING   comma delimited string of items to include for installation that are not included by default"
      echo "-j, --just_update_bash  	if this flag is used then the bash scripts is all that will update"
      exit 0
      ;;
    -e|--exclude)
      if $2 $# -gt 0; then
        exclusions=$1
      else
        echo "no exclusions specified"
        exit
      fi
      shift
      ;;

		-j|--just_update_bash)
        echo -e "\x1B[0;93mJust going to update the bash scripts \x1B[00m"
        just_update_bash=true
        shift
      ;;

    --bash_src_location)
        if $2 $# -gt 0; then
          bash_src_location="$2"
        else
          echo "no bash_src_location specified"
          exit
        fi

        shift
      ;;
    --skip_base)
      skip_base=true
      shift
      ;;
		-i|--include)
      if $2 $# -gt 0; then
        inclusions=$1
      else
        echo "no inclusions specified"
        exit
      fi
      shift
      ;;
    *)
      break
    ;;
    esac
done

# Only adds the string to the file if not already there
# Argument 1 (required) the file to look at and add to
# Argument 2 (required) is the String to Test (find in the file)
# Argument 3 (optional) if provided this will be the string that is inserted into the file
function addOnceTofile {
  # the file
  file=$1
  # String to find in file
  test=$2
  str=$3
  if [ -z "$3" ]
  then
    str=$test
  fi
  isIn=`grep "$test" $file && echo $?`
  if [ -z "$isIn" ]
  then
    echo "$str" >> $file
  fi
}

function check_tools(){
  RECEIPT_FILE=/var/db/receipts/com.apple.pkg.DeveloperToolsCLI.bom
  if [ -f "$RECEIPT_FILE" ]; then
    return 1
  else
    return 0
  fi
}

function install_cli_tools(){
  version=`system_profiler SPSoftwareDataType | grep "System Version" | awk '{print $5}' | awk -F"." '{print $2}'`
  if test "$version" -eq  9
  then
    hdiutil mount $tools_src_location/command_line_tools_os_x_mavericks_for_xcode__late_october_2013.dmg -nobrowse
    # Install the package
    echo "About to install. This will take a few minutes"
    sudo installer -pkg "/Volumes/Command Line Developer Tools/Command Line Tools (OS X 10.9).pkg" -target /
    # Unmount the package
    hdiutil unmount "/Volumes/Command Line Developer Tools"
  else
    hdiutil mount $tools_src_location/command_line_tools_os_x_mountain_lion_for_xcode__october_2013.dmg -nobrowse
    # Install the package
    echo "About to install. This will take a few minutes"
    sudo installer -pkg "/Volumes/Command Line Tools (Mountain Lion)/Command Line Tools (Mountain Lion).mpkg" -target /
    # Unmount the package
    hdiutil unmount "/Volumes/Command Line Tools (Mountain Lion)"
  fi
}

function installWithExclusionCheck() {
  if [[ $exclusions == *$1* ]]
  then
   echo "Excluded $1"
  else
   brew cask install $1
  fi
}

function mountShare(){
  echo $shared_local
  bmkdir $shared_local
  mount -t smbfs $shared_remote $shared_local
}

function updateBashProfile() {
   ###
   # Mount Shared Drive
   #
   mountShare

   # Create .bash_profile if it doesn't exist
   if [ ! -f $profile_file ]; then
       touch $profile_file
   fi


   # Add to bash_profile
   addOnceTofile $profile_file "export WORKSPACE=$workspace"
   if [ ! -d $bash_location ]; then
       mkdir $bash_location
   fi

   # Copy Profile Common content
   addOnceTofile $profile_file "### Common Inclusions ###"
   src=$bash_src_location
   echo "$src"
   for f in `ls -a "$src/"`
   do
     if [ -f "$src/$f" ]
     then
       value=`cat $src/$f`
       echo "$value" > $bash_location/$f
       addOnceTofile $profile_file $f "if [ -r $bash_location/$f ]; then . $bash_location/$f; fi;"
     fi
   done
   addOnceTofile $profile_file "###### inclusion end ###"

  # source it
  . $profile_file

}

###
# Bash Setup
#
read -p "Enter Workspace (press ENTER to use default $HOME/Development): " workspace
if [ -z "$workspace" ]; then
  workspace="$HOME/Development"
  mkdir $WORKSPACE
fi

exit 0

if $skip_base; then
  echo "skip base installs"
else
  updateBashProfile

  if $just_update_bash; then
   echo -e "\x1B[0;32mDone updating the bash scripts\x1B[0;"
   exit;
  fi

  ###
  # XCode Install
  #
  # Mount the package based on OS version
  if [[ $exclusions == *osxclitools* ]]
  then
    echo "Excluded Apple OSX CLI Tools"
  else
    # only add the tools if not present
    if check_tools -eq 0 ; then
     echo -e "\x1B[0;32mInstalling OSX Developer CLI Tools\x1B[00m... This will take awhile (about 10 minutes)"
     install_cli_tools
    else
     echo -e "OSX Developer CLI Tools already installed"
    fi
  fi
fi

###
# INSTALLERS
#

## Ruby
gem update --system

# Install HomeBrew
#     For more information: http://brew.sh/
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

# Brew Extension that allows GUI installations via CL and for other tools currently missing formulas (e.g. Vagrant)
#     For more information: https://github.com/phinze/homebrew-cask
brew tap phinze/homebrew-cask
brew install brew-cask

# The better CP command. Trust me, you'll like it.
brew install pv

###
# CORE TOOLS
#

# Install git
brew install git

# Install svn
brew install svn

# Install fontcustom
brew install fontforge ttfautohint
gem install fontcustom

# Install NodeJS
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | sh
. $HOME/.nvm/nvm.sh
nvm install 0.10
nvm use 0.10

# Proxy workarounds for NPM
npm config set strict-ssl false
npm config set registry "http://registry.npmjs.org/"

# Install Grunt CLI
npm install -g grunt-cli

# Install WGET (used to install other tools and just helpful)
brew install wget

# Install Virtualbox (only if not already installed)
installWithExclusionCheck virtualbox

# Install Extension pack regardless if already VirtualBox installation. This is to prevent a missing dependency. Mostly taken from http://alanthing.com/blog/2013/03/17/virtualbox-extension-pack-with-one-line/ with a few alterations
export version=$(/usr/bin/vboxmanage -v) && export var1=$(echo ${version} | cut -d 'r' -f 1) && export var2=$(echo ${version} | cut -d 'r' -f 2) && export file="Oracle_VM_VirtualBox_Extension_Pack-${var1}-${var2}.vbox-extpack" && curl --location http://download.virtualbox.org/virtualbox/${var1}/${file} -o ~/Downloads/${file} && sudo VBoxManage extpack install ~/Downloads/${file} --replace && sudo VBoxManage extpack cleanup && rm ~/Downloads/${file} && unset version var1 var2 file

# Install Vagrant
installWithExclusionCheck vagrant

# Install Boot2Docker
installWithExclusionCheck boot2docker


###
# GUI TOOLS
#
# Gasmask is a helpful tool for quickly managing your host file(s)
installWithExclusionCheck gas-mask

# For more information: http://www.alfredapp.com/
installWithExclusionCheck alfred

# For more information: http://www.sourcetreeapp.com/
installWithExclusionCheck sourcetree

# Browsers
installWithExclusionCheck google-chrome
installWithExclusionCheck firefox

# IDEs
installWithExclusionCheck intellij-idea
installWithExclusionCheck sublime-text

# Common utilies
installWithExclusionCheck clipmenu
installWithExclusionCheck iterm2
installWithExclusionCheck cocoarestclient
installWithExclusionCheck bettertouchtool
installWithExclusionCheck charles
installWithExclusionCheck skype

# Other software
installWithExclusionCheck adium
installWithExclusionCheck android-file-transfer
installWithExclusionCheck evernote
installWithExclusionCheck dropbox
installWithExclusionCheck keepassx
installWithExclusionCheck rescuetime
installWithExclusionCheck kaleidoscope
installWithExclusionCheck xquartz
installWithExclusionCheck sketch
installWithExclusionCheck dashlane
#installWithExclusionCheck google-drive


# TODO: Sublime Text 3 is no longer available for some reason
# installcask sublime-text3
# installcask vlc
# sublimeDir="~/Library/Application\ Support/Sublime\ Text\ 3"
# # Move sublime settings
# # install package control
# echo "Installing package control and syncing settings"
# wget -O ~/Library/Application\ Support/Sublime\ Text\ 3/Installed\ Packages/Package\ Control.sublime-package "https://sublime.wbond.net/Package%20Control.sublime-package" 
# # move sublime settings
# cp -R ../assets/sublime/ ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/
# # move sublime package control settings

# TODO: Add Package Control to Sublime (note the proxy settings in this command)
## import urllib.request,os,hashlib; h = '7183a2d3e96f11eeadd761d777e62404' + 'e330c659d4bb41d3bdf022e94cab3cd0'; pf = 'Package Control.sublime-package'; ipp = sublime.installed_packages_path(); urllib.request.install_opener( urllib.request.build_opener( urllib.request.ProxyHandler({"http":"http://connsvr.nike.com:8080"})) ); by = urllib.request.urlopen( 'http://sublime.wbond.net/' + pf.replace(' ', '%20')).read(); dh = hashlib.sha256(by).hexdigest(); print('Error validating download (got %s instead of %s), please try manual install' % (dh, h)) if dh != h else open(os.path.join( ipp, pf), 'wb' ).write(by)
# TODO: Add proxy settings to Sublime
## edit the Package Control user settings and add "http_proxy" and "https_proxy"

# TODO: Install compass
## sudo gem install --http-proxy http://connsvr.nike.com:8080 compass

# Manages integration with Alfred; allows applications installed with
# homebrew cask to be launched by Alfred by adding the Caskroom to Alfreds search paths
# Adds Caskroom to alfred search paths
brew cask alfred link
