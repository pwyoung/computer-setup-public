
# For 'm, z'
#   m: mark a directory
#   z: cd to the marked directory

z(){
  cd $(cat ~/.marked_path)
}

