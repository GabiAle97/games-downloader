#!/bin/bash

if [ ! -f /sdcard/darkos.metadata/metadata.pegasus.txt ]; then 
    mkdir -p /sdcard/darkos.metadata/   
    cp metadata.pegasus.txt.template /sdcard/darkos.metadata/metadata.pegasus.txt

    export PEGASUS_TOKEN=$(cat /data/data/com.termux.widget/shared_prefs/com.termux.widget_preferences.xml | grep token | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
    sed -i "s/<TOKEN>/${PEGASUS_TOKEN}/g" /sdcard/darkos.metadata/metadata.pegasus.txt
fi

if [ ! -f "/sdcard/darkos.metadata/$1" ]; then 
    touch "/sdcard/darkos.metadata/$1"
fi

name=$(echo "$2" | awk '{print tolower($0)}')
nameURLed=$(echo -n "$name" | jq -sRr @uri)
echo "Buscando $nameURLed en LaunchBox Games Database..."
echo "https://gamesdb.launchbox-app.com/games/results/?platform=windows&title=$nameURLed"
curl "https://gamesdb.launchbox-app.com/games/results/?platform=windows&title=$nameURLed" > temp.html
results=$(cat temp.html | grep "<h3 b-r4eeokcanc>" | awk '{print tolower($0)}' | awk -F '>' '{print $2}' | awk -F '<' '{print $1}' | wc -l)
echo "$results resultados encontrados para $nameURLed"
if [[ "$results" -lt "1" ]]; then
    echo "No results found for $name."
    lastWord=$(echo "$name" | awk '{print $NF}')
    name=$(echo "$name" | sed "s| $lastWord||g")
    if [[ "$lastWord" != "$name" ]];then
        echo "Trying to drop the last word and search again..."
        ./pegasus.sh "$1" "$name"
        exit 0
    else
        echo "No se han encontrado resultados para $name"
        exit 0
    fi
else
    if [[ "$results" == "1" ]]; then
        namefound=$(cat temp.html | grep "<h3 b-r4eeokcanc>" | awk '{print tolower($0)}' | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')
        echo "$(echo $namefound | sed 's/[^a-zA-Z0-9 ]//g') == $(echo $name | sed 's/[^a-zA-Z0-9 ]//g')"
        if [[ "$(echo $namefound | sed 's/[^a-zA-Z0-9 ]//g')" =~ "$(echo $name | sed 's/[^a-zA-Z0-9 ]//g')" ]]; then
            uri="$(cat temp.html | grep "href=\"/games/details/" | awk '{print $4}' | awk -F '=' '{print $2}' | awk -F '>' '{print $1}' | sed 's/\"//g')"
        else
            echo "No hay resultados de $name"
            exit 0            
        fi
    else
        sed -i "s|>|>\"|g" temp.html
        sed -i "s|<|\"<|g" temp.html
        echo "export results=(" > searchresults
        echo "export uris=(" > searchuris
        echo "$(cat temp.html | grep "<h3 b-r4eeokcanc>" | awk '{print tolower($0)}' | awk -F '>' '{print $2}' | awk -F '<' '{print $1}')" >> searchresults 
        echo "$(cat temp.html | grep "href=\"/games/details/" | awk '{print $4}' | awk -F '=' '{print $2}' | awk -F '>' '{print $1}')" >> searchuris
        echo ")" >> searchresults
        echo ")" >> searchuris
        source searchresults
        source searchuris
        position=0
        counter=1
        echo "export index=(" > searchindex
        echo "Existen estos datos sobre $name:"
        for i in "${results[@]}"; do
            if [[ "$i" =~ "$name" ]]; then
                echo "$counter) $i"
                counter=$((counter + 1))
                echo "\"$position\"" >> searchindex
            fi
            position=$((position + 1))
        done
        echo ")" >> searchindex
        source searchindex
        read -p "Selecciona el número del resultado que quieres usar: " index
        if [[ -z "$index" ]]; then
            echo "No se ha seleccionado ningún resultado"
        else
            export uri="${uris[$index-1]}"
        fi
    fi
    curl "https://gamesdb.launchbox-app.com$uri" > game.html
    tidy -indent -wrap 0 -quiet yes -utf8 -modify game.html &>/dev/null
    mkdir -p assets/covers/
    mkdir -p assets/screenshots/
    mkdir -p assets/background/
    mkdir -p assets/video/
    mkdir -p assets/video/temp/
    title=$(cat game.html | grep "<title>" | sed "s|<title>||g" | sed "s| - LaunchBox Games Database</title>||g")
    developer=$(cat game.html | grep "<a href=\"https://gamesdb.launchbox-app.com/developers/games" | grep -oP 'href="\K[^"]+' | awk -F "https://gamesdb.launchbox-app.com/" '{print $2}' | sed "s|-| |g" | awk '{print $2}')
    publisher=$(cat game.html | grep "<a href=\"https://gamesdb.launchbox-app.com/publishers/games" | grep -oP 'href="\K[^"]+' | awk -F "https://gamesdb.launchbox-app.com/" '{print $2}' | sed "s|-| |g" | awk '{print $2}')
    genre=$(cat game.html | grep https://gamesdb.launchbox-app.com/genres/games | grep -oP 'href="\K[^"]+' | awk -F "https://gamesdb.launchbox-app.com/" '{print $2}' | sed "s|-| |g" | awk '{print $2}' | sed ':a;N;$!ba;s/\n/, /g')
    description=$(cat game.html | grep "meta name=\"description" | grep -oP 'content="\K[^"]+')
    movie=$(sed -n "$(($(cat game.html | grep -n Video | cut -d: -f1) + 1))p" game.html | grep -oP 'href="\K[^"]+')
    maxPlayers=$(sed -n "$(($(cat game.html | grep -n "Max Players" | cut -d: -f1) + 1))p" game.html | awk -F ">" '{print $5}' | awk -F "<" '{print $1}')
    releaseDate=$(date -d "$(sed -n "$(($(cat game.html | grep -n "Release Date" | cut -d: -f1) + 1))p" game.html | awk -F ">" '{print $5}' | awk -F "<" '{print $1}')" +"%Y-%m-%d")
    rating=$(echo "scale=2; ($(cat game.html | grep "Game rating of" | grep -oP 'style="width:\K[^"]+' | awk -F "em;" '{print $1}') / 5) * 100" | bc |  awk -F "." '{print $1}')
    echo "export imgsrcs=(" > imgsrcs
    echo "export imgname=(" > imgname
    cat game.html | grep "images" | grep -oP 'src="\K[^"]+' | sed 's/^/"/; s/$/"/' >> imgsrcs
    cat game.html | grep "images" | grep -oP 'alt="\K[^"]+' | sed 's/^/"/; s/$/"/' >> imgname
    echo ")" >> imgsrcs
    echo ")" >> imgname
    source imgsrcs
    source imgname
    counter=0
    shotnum=1
    for i in "${imgname[@]}"; do
        echo "Imagen: $i"
        if [[ "$i" =~ "Box" ]]; then
            if [[ "$i" =~ "Front" ]]; then
                if [[ "$(ls assets/covers/"$1".boxfront*)" == "" ]]; then
                    wget -q "${imgsrcs[$counter]}" -O "assets/covers/$1.boxfront.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
                    export boxfront="assets/covers/$1.boxfront.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
                fi
            fi
        elif [[ "$i" =~ "Screenshot" ]]; then
            if [[ ! -f "assets/screenshots/$1.screenshot.$shotnum.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')" ]]; then
                wget -q "${imgsrcs[$counter]}" -O "assets/screenshots/$1.screenshot.$shotnum.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
            fi
            shotnum=$((shotnum + 1))
        elif [[ "$i" =~ "Logo" ]]; then
            if [[ "$(ls assets/covers/"$1".logo.*)" == "" ]]; then
                wget -q "${imgsrcs[$counter]}" -O "assets/covers/$1.logo.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
                export logo="assets/covers/$1.logo.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
            fi
        elif [[ "$i" =~ "Illustration" ]]; then
            if [[ "$(ls assets/covers/"$1".background.*)" == "" ]]; then
                wget -q "${imgsrcs[$counter]}" -O "assets/background/$1.background.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
                export background="assets/background/$1.background.$(echo "${imgsrcs[$counter]}" | awk -F '.' '{print $NF}')"
            fi
        
        fi
        counter=$((counter + 1))
    done
    if [[ "$movie" != "" ]]; then
        if [[ ! -f "assets/video/$1.*" ]]; then
            read -p "¿Quieres descargar el video? (s/n): " downloadVideo
            if [[ "$downloadVideo" != "s" && "$downloadVideo" != "S" ]]; then
                echo "No se descargará el video."
            else
                if [[ "$movie" =~ "youtube" ]]; then
                    yt-dlp $movie -o "assets/video/$1"
                    export videoExtension=$(ls assets/video/"$1".* | awk -F '.' '{print $NF}')
                else
                    wget -q "$movie" -O "assets/video/temp/"
                    videoExtension=$(ls assets/video/temp | awk -F '.' '{print $NF}')
                    mv assets/video/temp/* "assets/video/$1.$videoExtension"
                fi
            fi
        fi
    fi

    echo "" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "game: $title" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "file: $1" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "developer: $developer" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "publisher: $publisher" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "genre: $genre" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "description: $description" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "players: $maxPlayers" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "release: $releaseDate" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "rating: ${rating}%" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "assets.boxfront: $boxfront" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "assets.logo: $logo" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    echo "assets.background: $background" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    if [[ "$downloadVideo" == "s" || "$downloadVideo" == "S" ]]; then
        echo "assets.video: assets/video/$1.$videoExtension" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    fi
    echo "assets.screenshot:[ " >> /sdcard/darkos.metadata/metadata.pegasus.txt
    for i in assets/screenshots/"$1".screenshot.*; do
        echo "    $i" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    done
    echo " ]" >> /sdcard/darkos.metadata/metadata.pegasus.txt
    cp -r assets /sdcard/darkos.metadata/
    echo "Metadata for $title has been created successfully."
     

fi