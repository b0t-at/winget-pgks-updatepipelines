import os
import yaml
import requests
import sqlite3
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

manifestFolderPath = "<manifestFolderPath>"
db_path = "failing_installers.db"
max_workers = 500

def setup_database(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS parsed_data (
            id INTEGER PRIMARY KEY,
            package_identifier TEXT,
            package_version TEXT,
            installer_url TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS failing_installers (
            id INTEGER PRIMARY KEY,
            package_identifier TEXT,
            package_version TEXT,
            installer_url TEXT
        )
    ''')
    conn.commit()
    conn.close()

def parse_yaml_file(file_path):
    with open(file_path, 'r', encoding="utf-8") as stream:
        try:
            data = yaml.safe_load(stream)
            package_identifier = data.get("PackageIdentifier")
            package_version = data.get("PackageVersion")
            installer_urls = []
            if "Installers" in data:
                for installer in data["Installers"]:
                    if "InstallerUrl" in installer:
                        installer_urls.append(installer["InstallerUrl"])
            return package_identifier, package_version, installer_urls
        except yaml.YAMLError as exc:
            print(f"Error parsing {file_path}: {exc}")
            return None, None, []

def parse_and_extract_yaml_files(folder_path, db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    def process_directory(root, files):
        for file in files:
            if file.endswith(".installer.yaml"):
                file_path = os.path.join(root, file)
                package_identifier, package_version, installer_urls = parse_yaml_file(file_path)
                if package_identifier and package_version:
                    for installer_url in installer_urls:
                        cursor.execute('''
                            INSERT INTO parsed_data (package_identifier, package_version, installer_url)
                            VALUES (?, ?, ?)
                        ''', (package_identifier, package_version, installer_url))
                        # output the id of the row just inserted
                        print(cursor.last)

    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        print (f"Processing {folder_path}...")
        futures = []
        for root, dirs, files in os.walk(folder_path):
            futures.append(executor.submit(process_directory, root, files))

        print("Waiting for futures to complete...")

        with tqdm(total=len(futures)) as pbar:    
            for future in as_completed(futures):
                future.result()
                pbar.update(1)
    
    conn.commit()
    conn.close()

def check_link(package_identifier, package_version, installer_url):
    response = requests.head(installer_url)
    if response.status_code != 200:
        return (package_identifier, package_version, installer_url)
    return None

def check_links_and_flag_failures(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT package_identifier, package_version, installer_url FROM parsed_data')
    rows = cursor.fetchall()
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(check_link, row[0], row[1], row[2]): row for row in rows}
        for future in as_completed(futures):
            result = future.result()
            if result:
                package_identifier, package_version, installer_url = result
                cursor.execute('''
                    INSERT INTO failing_installers (package_identifier, package_version, installer_url)
                    VALUES (?, ?, ?)
                ''', (package_identifier, package_version, installer_url))
    
    conn.commit()
    conn.close()

def generate_report(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM failing_installers')
    rows = cursor.fetchall()
    for row in rows:
        print(f"PackageIdentifier: {row[1]}, PackageVersion: {row[2]}, InstallerUrl: {row[3]}")
    conn.close()

# debug: delete failing installers file
if os.path.exists(db_path):
    os.remove(db_path)


print("Starting dead-link script...")

# Setup database
setup_database(db_path)

# Parse and extract YAML files
parse_and_extract_yaml_files(manifestFolderPath, db_path)

# Check links and flag failures
check_links_and_flag_failures(db_path)

# Generate report
generate_report(db_path)