import os
import sys

def group(data, group_size):
    return [data[i:i+group_size] for i in range(0, len(data), group_size)]

def write_file(output_dir, filename, content):
    """Write content to an assembly file."""
    if output_dir is None:
        output_dir = "."
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    output_file = os.path.join(output_dir, filename)
    
    try:
        with open(output_file, "w") as f:
            f.write(content)
    except Exception as e:
        print(f"Error: Could not write file: {output_file}\n{e}")
        sys.exit(1)

    print(f"Wrote {output_file}")
