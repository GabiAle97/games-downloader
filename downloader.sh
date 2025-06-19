#!/bin/bash

# Path to the image
#IMAGE_PATH="test.png"
#jp2a "$IMAGE_PATH"
#
# Get all links from the Telegram chat and save to a file
#wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" -qO- "https://library.hydra.wiki/library" > links.txt

#pip3 install requirements.txt
#python3 downloader.py


hydralinks=("https://hydralinks.pages.dev/sources/steamrip.json" "https://hydralinks.pages.dev/sources/gog.json" "https://hydrasources.su/hydra.json" "https://hydralinks.pages.dev/sources/atop-games.json")
if [ ! -f gamesobtained ]; then
  pkg install aria2 jq python-pip libxml2 libxslt unrar -y
  pip3 install -r requirements.txt
  echo "GENERATING GAMELIST"
  echo ""
  for i in "${hydralinks[@]}"; do
    echo "obtaining $i"
    curl "$i" > gamelist
    export origin=$(echo "$i" | sed 's/https:\/\/hydralinks\.pages\.dev\/sources\///g' | sed 's/https:\/\/hydrasources\.su\///g' | sed 's/\.json//g')
    jq . gamelist > gamelist.json && rm gamelist
    echo "export nombres=(" > gamenames$origin.env
    echo "export url=(" > gameurls$origin.env
    echo "export filesizes=(" > gamefs$origin.env
    jq '.downloads[].title' gamelist.json >> gamenames$origin.env
    jq '.downloads[].uris[0]' gamelist.json >> gameurls$origin.env
    jq '.downloads[].fileSize' gamelist.json >> gamefs$origin.env
    echo "Games obtained: $(jq '.downloads | length' gamelist.json)" && rm gamelist.json
    echo ")" >> gamenames$origin.env
    echo ")" >> gameurls$origin.env
    echo ")" >> gamefs$origin.env
    sed -i 's/`//g' gamenames$origin.env
    sed -i 's/`//g' gameurls$origin.env
    sed -i 's/`//g' gamefs$origin.env
    touch gamesobtained
  done

fi 

echo "Selecciona el origen de los juegos:"
counter=1
for i in "${hydralinks[@]}"; do
  printf "%s %s\n" "$counter) $i"
  counter=$((counter + 1))
done
read -p "Seleccion: " origen

while [ "$origen" -lt 1 ] || [ "$origen" -gt "$((counter - 1))" ]; do
    echo "Opción $origen incorrecta!"
    echo "Selecciona el origen de los juegos:"
    counter=1
    for i in "${hydralinks[@]}"; do
      printf "%s %s\n" "$counter) $i"
      counter=$((counter + 1))
    done
    read -p "Seleccion: " origen
done

export origin=$(echo "${hydralinks[$origen-1]}" | sed 's/https:\/\/hydralinks\.pages\.dev\/sources\///g' | sed 's/https:\/\/hydrasources\.su\///g' | sed 's/\.json//g')
# Declarar los arrays
source gameurls$origin.env
source gamenames$origin.env
source gamefs$origin.env

# Buscador en el array de nombres
read -p "Ingresa el nombre del juego: " busqueda
coincidencias=()
mapfile -t coincidencias < <(printf "%s\n" "${nombres[@]}" | grep -i "$busqueda" -n | cut -d: -f1)

if [ ${#coincidencias[@]} -lt 1 ]; then
  echo "No se encontraron coincidencias."
  ./downloader.sh
  exit 0
fi

echo "Elige el juego que vas a descargar:"
counter=1
for i in "${coincidencias[@]}"; do
  printf "%s %s\n" "$counter) ${nombres[$i-1]}"
  counter=$((counter + 1))
done
printf "%s %s\n" "$counter) Volver al menú principal"
echo ""
read -p "Opción: " seleccion

while [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "$counter" ]; do
    echo "opcion $seleccion incorrecta! "
    echo "Elige el juego que vas a descargar:"
    counter=1
    for i in "${coincidencias[@]}"; do
    printf "%s %s\n" "$counter) ${nombres[$i-1]}"
    counter=$((counter + 1))
    done
    echo ""
    read -p "Opción: " seleccion
done
if [ "$seleccion" -eq "$counter" ]; then
  ./downloader.sh
  exit 0
fi
counter=$((counter - 1))
seleccion=$((seleccion - 1))
echo "Va a descargar ${nombres[${coincidencias[$seleccion]}-1]} (Tamaño: ${filesizes[${coincidencias[$seleccion]}-1]}). Presione cualquier tecla para continuar..."
read
url=$(printf "%s\n" "${url[${coincidencias[$seleccion]}-1]}")
url=$(echo $url | sed 's/"//g')

mkdir -p $PREFIX/glibc/opt/G_drive/downloaded
mkdir -p $PREFIX/glibc/opt/G_drive/installed

if [[ "$url" =~ "gofile" ]]; then
  cp gofile-downloader.py $PREFIX/glibc/opt/G_drive/
  cd $PREFIX/glibc/opt/G_drive/
  python3 gofile-downloader.py $url
  mv $(basename $url)/* ./downloaded/
  rm -rf $(basename $url)
  rm gofile-downloader.py
  cd -
fi

if [[ "$url" =~ "1fichier" ]]; then
  python3 1fichier-downloader.py --no-proxy $url $PREFIX/glibc/opt/G_drive/downloaded/
fi

if [[ "$url" =~ "magnet" ]]; then
  cd $PREFIX/glibc/opt/G_drive/installed
  aria2c --seed-time=0 $url
  cd -
fi

cd $PREFIX/glibc/opt/G_drive/
gamefolder=$(ls downloaded | awk -F '.' '{print $1}')
mkdir -p installed/$gamefolder
if [[ "$(ls downloaded)" =~ "rar" ]];then
    unrar x downloaded/*.rar installed/$gamefolder
    rm -rf downloaded/*.rar
  fi
  if [[ "$(ls downloaded)" =~ "zip" ]];then
    unzip downloaded/*.zip -d installed/$gamefolder
    rm -rf downloaded/*.zip
  fi
  if [[ "$(ls downloaded)" =~ "7z" ]];then
    7z x downloaded/*.7z -oinstalled/$gamefolder
    rm -rf downloaded/*.7z
  fi
  if [[ "$(ls downloaded)" =~ "tar" ]];then
    tar -xf downloaded/*.tar -C installed/$gamefolder
    rm -rf downloaded/*.tar
  fi
  if [[ "$(ls downloaded)" =~ "tar.gz" ]];then
    tar -xzf downloaded/*.tar.gz -C installed/$gamefolder
    rm -rf downloaded/*.tar.gz
  fi
  if [[ "$(ls downloaded)" =~ "tar.xz" ]];then
    tar -xJf downloaded/*.tar.xz -C installed/$gamefolder
    rm -rf downloaded/*.tar.xz
  fi
  if [[ "$(ls downloaded)" =~ "tar.bz2" ]];then
    tar -xjf downloaded/*.tar.bz2 -C installed/$gamefolder
    rm -rf downloaded/*.tar.bz2
  fi

  cd -

  echo "Juego instalado en $PREFIX/glibc/opt/G_drive/installed/$gamefolder"
  echo "Creando Acceso directo en escritorio..."

  echo "Selecciona el exe del juego:"
  counter=1
  mapfile -t array < <(find $PREFIX/glibc/opt/G_drive/installed/$gamefolder -type f -name "*.exe" | sed 's| |<SPACE>|')

  for i in ${array[@]}; do
    i=$(echo "$i" | sed 's|<SPACE>| |')
    printf "%s) %s\n" "$counter" "$i"
    counter=$((counter + 1))
  done
  echo "$counter) Volver al menú principal"
  echo ""
  read -p "Opción: " exe_seleccion
  while [ "$exe_seleccion" -lt 1 ] || [ "$exe_seleccion" -gt "$counter" ]; do
      echo "Opción $exe_seleccion incorrecta!"
      echo "Selecciona el exe del juego:"
      counter=1
      for i in ${array[@]}; do
        # Reemplazar <SPACE> por un espacio real para mostrar correctamente
        i=$(echo "$i" | sed 's|<SPACE>| |')
        printf "%s) %s\n" "$counter" "$i"
        counter=$((counter + 1))
      done
      echo "$counter) Volver al menú principal"
      echo ""
      read -p "Opción: " exe_seleccion
  done
  if [ "$exe_seleccion" -eq "$counter" ]; then
    exit 0
  fi
  dir=$(echo "${array[$exe_seleccion-1]}" | sed 's|<SPACE>| |')
  basename=$(echo $dir | sed 's|.*/||; s|\.[^.]*$||')
  cp link.sh.template ~/.shortcuts/$basename.sh
  sed -i "s|<PATH>|\"$(realpath "$dir")\"|g" ~/.shortcuts/$basename.sh