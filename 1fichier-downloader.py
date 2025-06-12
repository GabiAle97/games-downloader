import requests
import math
import os
import time
import lxml.html
import argparse
from random import choice

# Use a reliable proxy API
PROXY_API = 'https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=10000&country=all'
PLATFORM = os.name
MAX_PROXY_RETRIES = 5  # Limit proxy fetch retries

def get_proxy():
    try:
        response = requests.get(PROXY_API, timeout=10)
        response.raise_for_status()
        proxies = response.text.splitlines()
        proxy = choice(proxies).rstrip() if proxies else None
        if proxy:
            print(f"Fetched proxy: {proxy}")
            return proxy
        else:
            print("No proxies available from proxyscrape.com")
            return None
    except Exception as e:
        print(f"Error fetching proxy from proxyscrape.com: {e}")
        return None

def convert_size(size_bytes):
    if size_bytes == 0:
        return '0 B'
    size_name = ('B', 'KB', 'MB', 'GB', 'TB')
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return f'{s} {size_name[i]}'

def download_speed(bytes_read, start_time):
    if bytes_read == 0:
        return '0 B/s'
    elif time.time() - start_time == 0:
        return '- B/s'
    size_name = ('B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s')
    bps = bytes_read / (time.time() - start_time)
    i = int(math.floor(math.log(bps, 1024)))
    p = math.pow(1024, i)
    s = round(bps / p, 2)
    return f'{s} {size_name[i]}'

def get_link_info(url):
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        html = lxml.html.fromstring(r.content)
        if html.xpath('//*[@id="pass"]'):
            return ['Private File', '- MB']
        name = html.xpath('//td[@class="normal"]')[0].text
        size = html.xpath('//td[@class="normal"]')[2].text
        return [name, size]
    except Exception as e:
        print(f"Error getting link info: {e}")
        return None

def download(url, dl_directory, dl_name=None, payload={'dl_no_ssl': 'on', 'dlinline': 'on'}, downloaded_size=0, use_proxy=True):
    if not os.path.exists(dl_directory):
        os.makedirs(dl_directory)

    if dl_name and os.path.exists(f"{dl_directory}/{dl_name}"):
        try:
            downloaded_size = os.path.getsize(f"{dl_directory}/{dl_name}")
        except FileNotFoundError:
            downloaded_size = 0

    i = 1
    password = None
    proxies = None
    while i <= MAX_PROXY_RETRIES:
        if use_proxy:
            print(f"Bypassing attempt ({i}/{MAX_PROXY_RETRIES}) with proxy")
            proxy = get_proxy()
            if not proxy:
                print("Failed to fetch a valid proxy")
                i += 1
                time.sleep(1)
                continue
            proxies = {'http': proxy} if PLATFORM == 'nt' else {'http': f'http://{proxy}'}
        else:
            print("Attempting download without proxy")
            proxies = None
            i = MAX_PROXY_RETRIES  # Skip retries if not using proxy

        try:
            r = requests.post(url, data=payload, proxies=proxies, timeout=10)
            r.raise_for_status()
            html = lxml.html.fromstring(r.content)
            if html.xpath('//*[@id="pass"]'):
                if not password:
                    password = input("Enter password for the file (or press Enter to skip): ")
                if password:
                    payload['pass'] = password
                r = requests.post(url, data=payload, proxies=proxies, timeout=10)
                r.raise_for_status()
        except Exception as e:
            print(f"Request failed: {e}")
            if not use_proxy:
                print("Failed without proxy, exiting")
                return None
            i += 1
            time.sleep(1)
            continue
        else:
            print("Bypassed successfully")
            break
    else:
        print(f"Failed to bypass after {MAX_PROXY_RETRIES} attempts")
        if use_proxy:
            print("Retrying without proxy...")
            return download(url, dl_directory, dl_name, payload, downloaded_size, use_proxy=False)
        return None

    if not html.xpath('/html/body/div[4]/div[2]/a'):
        if 'Bad password' in r.text:
            print("Wrong password")
            password = input("Enter password again (or press Enter to skip): ")
            if password:
                payload['pass'] = password
            return download(url, dl_directory, dl_name, payload, downloaded_size, use_proxy)
    else:
        old_url = url
        url = html.xpath('/html/body/div[4]/div[2]/a')[0].get('href')

        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.131 Safari/537.36',
            'Referer': old_url,
            'Range': f'bytes={downloaded_size}-'
        }

        try:
            r = requests.get(url, stream=True, headers=headers, proxies=proxies, timeout=10)
            r.raise_for_status()
            if 'Content-Disposition' in r.headers:
                name = r.headers['Content-Disposition'].split('"')[1]
                if dl_name:
                    name = dl_name
                elif os.path.exists(f'{dl_directory}/{name}'):
                    j = 1
                    while os.path.exists(f'{dl_directory}/({j}) {name}'):
                        j += 1
                    name = f'({j}) {name}'

                name = f'{name}.unfinished' if name[-11:] != '.unfinished' else name
                print(f"Downloading {name[:-11]} (Size: {convert_size(float(r.headers.get('Content-Length', 0)) + downloaded_size)})")

                with open(f"{dl_directory}/{name}", 'ab') as f:
                    print("Downloading...")
                    chunk_size = 1024
                    bytes_read = 0
                    start = time.time()
                    try:
                        for chunk in r.iter_content(chunk_size):
                            f.write(chunk)
                            bytes_read += len(chunk)
                            total_per = 100 * (float(bytes_read) + downloaded_size) / (float(r.headers.get('Content-Length', 0)) + downloaded_size)
                            dl_speed = download_speed(bytes_read, start)
                            print(f"\rProgress: {round(total_per, 1)}% | Speed: {dl_speed}", end="")
                        print("\nDownload complete")
                        os.rename(f"{dl_directory}/{name}", f"{dl_directory}/{name[:-11]}")
                        return name[:-11]
                    except KeyboardInterrupt:
                        print("\nDownload interrupted, saving partial file")
                        return name  # Return .unfinished file name
            else:
                print("No content disposition, retrying...")
                return download(url, dl_directory, dl_name, payload, downloaded_size, use_proxy)
        except Exception as e:
            print(f"Download failed: {e}")
            return None

def main():
    parser = argparse.ArgumentParser(description="Download a file from a URL with optional proxy support.")
    parser.add_argument('url', help="URL of the file to download")
    parser.add_argument('directory', help="Directory to save the downloaded file")
    parser.add_argument('--no-proxy', action='store_true', help="Skip using proxies")
    args = parser.parse_args()

    # Suppress SSL warnings (for debugging only, not secure)
    requests.packages.urllib3.disable_warnings()

    result = download(args.url, args.directory, use_proxy=not args.no_proxy)
    if result:
        print(f"File downloaded successfully: {result}")
    else:
        print("Download failed or was interrupted.")

if __name__ == "__main__":
    main()