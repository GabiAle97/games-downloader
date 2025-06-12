#!/bin/bash

# Path to the image
#IMAGE_PATH="test.png"
#jp2a "$IMAGE_PATH"
#
# Get all links from the Telegram chat and save to a file
#wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" -qO- "https://library.hydra.wiki/library" > links.txt

#pip3 install requirements.txt
#python3 downloader.py

pkg install aria2c

hydralinks=("https://hydralinks.pages.dev/sources/steamrip.json" "https://hydralinks.pages.dev/sources/gog.json" "https://hydrasources.su/hydra.json" "https://hydralinks.pages.dev/sources/atop-games.json")
if [ ! -f gamesobtained ]; then
  echo "GENERATING GAMELIST"
  echo ""
  for i in "${hydralinks[@]}"; do
    echo "obtaining $i"
    curl "$i" > gamelist
    jq . gamelist > gamelist.json && rm gamelist
    export origin=$(echo "$i" | sed 's/https:\/\/hydralinks\.pages\.dev\/sources\///g' | sed 's/https:\/\/hydrasources\.su\///g' | sed 's/\.json//g')
    echo "export nombres=(" > gamenames$origin.env
    echo "export url=(" > gameurls$origin.env
    jq '.downloads[].title' gamelist.json >> gamenames$origin.env
    jq '.downloads[].uris[0]' gamelist.json >> gameurls$origin.env
    echo "Games obtained: $(jq '.downloads | length' gamelist.json)" && rm gamelist.json
    echo ")" >> gamenames$origin.env
    echo ")" >> gameurls$origin.env
    sed -i 's/`//g' gamenames$origin.env
    sed -i 's/`//g' gameurls$origin.env
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

# Buscador en el array de nombres
read -p "Ingresa el nombre del juego: " busqueda
encontrado=false
coincidencias=()
for i in "${!nombres[@]}"; do
  if [[ "${nombres[i],,}" =~ "${busqueda,,}" ]]; then
    coincidencias+=("$i")
    encontrado=true
  fi
done

if [ "$encontrado" = false ]; then
  echo "No se encontraron coincidencias."
  ./downloader.sh
  exit 0
fi

echo "Elige el juego que vas a descargar:"
counter=1
for i in "${coincidencias[@]}"; do
  printf "%s %s\n" "$counter) ${nombres[$i]}"
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
    printf "%s %s\n" "$counter) ${nombres[$i]}"
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
seleccion=$(($seleccion - 1))
printf "%s\n" "${url[${coincidencias[$seleccion]}]}"
url=$(printf "%s\n" "${url[${coincidencias[$seleccion]}]}")
url=$(echo $url | sed 's/"//g')

pip3 install -r requirements.txt

if [[ "$url" =~ "gofile" ]]; then
  cp gofile-downloader.py $PREFIX/glibc/opt/G_drive/
  cd $PREFIX/glibc/opt/G_drive/
  python3 gofile-downloader.py $url
  rm gofile-downloader.py
  cd -
fi

if [[ "$url" =~ "1fichier" ]]; then
  cp 1fichier-downloader.py $PREFIX/glibc/opt/G_drive/
  cd $PREFIX/glibc/opt/G_drive/
  python3 1fichier-downloader.py $url
  rm 1fichier-downloader.py
  cd -
fi

if [[ "$url" =~ "magnet" ]]; then
  cd $PREFIX/glibc/opt/G_drive/
  aria2c $url
  cd -
fi

