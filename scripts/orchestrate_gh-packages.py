import os
import glob
import yaml

# Paths
base_dir = os.path.dirname(os.path.abspath(__file__))
monitored_file = os.path.join(base_dir, "../github-releases-monitored.yml")
workflows_dir = os.path.join(base_dir, "../.github/workflows")
template_file = os.path.join(base_dir, "../.github/workflows-templates/github-releases.yml")

# Constants
batch_size = 250
workflow_prefix = "update-github-packages-"
workflow_suffix = ".yml"

# Step 1: Read the monitored file
with open(monitored_file, "r") as file:
    monitored_data = yaml.safe_load(file)

# Step 2: Split the objects into batches of 250
batches = [monitored_data[i:i + batch_size] for i in range(0, len(monitored_data), batch_size)]

# Step 3: Delete existing workflow files
existing_workflows = glob.glob(os.path.join(workflows_dir, f"{workflow_prefix}*{workflow_suffix}"))
for workflow in existing_workflows:
    os.remove(workflow)

# Step 4: Create new workflow files
with open(template_file, "r") as file:
    template_content = file.read()

for index, batch in enumerate(batches, start=1):
    workflow_file = os.path.join(workflows_dir, f"{workflow_prefix}{index}{workflow_suffix}")
    
    # Prepare the include section as a YAML string
    include_section = "\n".join(
        f"          - id: {item['id']}\n"
        f"            repo: {item['repo']}\n"
        f"            url: {item['url']}" for item in batch
    )
    
    # Replace the placeholder with the include section
    updated_content = template_content.replace(
        "# Orchestrator will insert Packages here",
        include_section
    )
    
    # Write the new workflow file
    with open(workflow_file, "w") as file:
        file.write(updated_content)

print(f"Generated {len(batches)} workflow files in {workflows_dir}.")