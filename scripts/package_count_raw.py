import sys
import yaml

def count_packages(file_path):
    with open(file_path, 'r') as file:
        data = yaml.safe_load(file)
        return len(data)

if len(sys.argv) < 2:
    print("Please provide the file path as an argument.")
    sys.exit(1)

file_path = sys.argv[1]
package_count = count_packages(file_path)
print(package_count)