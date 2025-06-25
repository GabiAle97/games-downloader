#!/bin/bash


hydralinks=(
"https://hydralinks.pages.dev/sources/steamrip.json"
"https://hydralinks.pages.dev/sources/gog.json"
"https://hydrasources.su/hydra.json"
"https://hydralinks.pages.dev/sources/atop-games.json"
"https://hydralinks.pages.dev/sources/dodi.json"
"https://hydralinks.pages.dev/sources/kaoskrew.json"
"https://hydralinks.pages.dev/sources/tinyrepacks.json")
if [ ! -f gamesobtained ]; then
  pkg install aria2 jq python-pip libxml2 libxslt unrar icoutils tidy -y
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
    echo "Opcion $origen incorrecta!"
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
printf "%s %s\n" "$counter) Volver al menu principal"
echo ""
read -p "Opcion: " seleccion

while [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "$counter" ]; do
    echo "opcion $seleccion incorrecta! "
    echo "Elige el juego que vas a descargar:"
    counter=1
    for i in "${coincidencias[@]}"; do
    printf "%s %s\n" "$counter) ${nombres[$i-1]}"
    counter=$((counter + 1))
    done
    echo ""
    read -p "Opcion: " seleccion
done
if [ "$seleccion" -eq "$counter" ]; then
  ./downloader.sh
  exit 0
fi
counter=$((counter - 1))
seleccion=$((seleccion - 1))
echo "Va a descargar ${nombres[${coincidencias[$seleccion]}-1]} (Peso: ${filesizes[${coincidencias[$seleccion]}-1]}). Presione cualquier tecla para continuar..."
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
  mapfile -t array < <(find $PREFIX/glibc/opt/G_drive/installed/$gamefolder -type f -name "*.exe" | sed 's| |<SPACE>|g')

  for i in ${array[@]}; do
    i=$(echo "$i" | sed 's|<SPACE>| |g')
    printf "%s) %s\n" "$counter" "$i"
    counter=$((counter + 1))
  done
  echo "$counter) Volver al menu principal"
  echo ""
  read -p "Opcion: " exe_seleccion
  while [ "$exe_seleccion" -lt 1 ] || [ "$exe_seleccion" -gt "$counter" ]; do
      echo "Opcion $exe_seleccion incorrecta!"
      echo "Selecciona el exe del juego:"
      counter=1
      for i in ${array[@]}; do
        # Reemplazar <SPACE> por un espacio real para mostrar correctamente
        i=$(echo "$i" | sed 's|<SPACE>| |g')
        printf "%s) %s\n" "$counter" "$i"
        counter=$((counter + 1))
      done
      echo "$counter) Volver al menu principal"
      echo ""
      read -p "Opcion: " exe_seleccion
  done
  if [ "$exe_seleccion" -eq "$counter" ]; then
    exit 0
  fi
  dir=$(echo "${array[$exe_seleccion-1]}" | sed 's|<SPACE>| |g')
  basename=$(echo $dir | sed 's|./||; s|\.[^.]$||')
  cp link.sh.template "/data/data/com.termux/files/home/.shortcuts/$basename.sh"
  sed -i "s|<PATH>|\"$(realpath "$dir")\"|g" "/data/data/com.termux/files/home/.shortcuts/$basename.sh" && chmod +x "/data/data/com.termux/files/home/.shortcuts/$basename.sh"
  wrestool -x --type=14 "$dir" > icon.ico && icotool -x -w$(icotool -l icon.ico | awk '{print $3}' | awk -F "=" '{print $2}' | sort -nr | head -n1) icon.ico && mv *.png "$basename.sh.png" && mv "$basename.sh.png" /data/data/com.termux/files/home/.shortcuts/icons/ && rm icon.ico

  echo "Acceso directo creado en /data/data/com.termux/files/home/.shortcuts/$basename.sh"
  read -p "Desea agregar el acceso directo a la pantalla principal? (s/n): " agregar
  if [[ "$agregar" == "s" || "$agregar" == "S" ]]; then
    echo "Cuando se abra la ventana \"Termux Shortcut\", seleccione la opcion \"$basename.sh\" para agregar a la pantalla principal. "
    read -p "Presione Enter para continuar..."
    am start -n com.termux.widget/.TermuxCreateShortcutActivity
  fi

  read -p "Desea generar los metadatos para utilizar en Pegasus? (s/n): " addPegasus
  if [[ "$addPegasus" == "s" || "$addPegasus" == "S" ]]; then
    finalname=$(echo "${nombres[${coincidencias[$seleccion]}-1]}" | sed -E 's/ *([vV][0-9][^ ]*|[+].*|GOG|FitGirl|Repack).*//' | sed "s|(||g" | sed -E 's/(alpha|beta|v)?[[:space:]]*[0-9]+\.[0-9]+(\.[0-9]+)?[^ ]*.*//I' | sed -E 's/(build)[[:space:]]*[0-9]+(\.[0-9]+)*[^ ]*.*//I' | sed -E 's/\b(Complete Edition|Deluxe Edition|Free Download|Full Game|Repack|GOG|FitGirl|All DLCs)\b//Ig' | sed "s|\.| |g")
    pegasus.sh "$basename.sh" "$finalname"
  fi