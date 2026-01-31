import os

def write_file(output_dir: str, filename: str, content: str):
    """Write content to a file."""
    if output_dir is None:
        output_dir = "."
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    output_file = os.path.join(output_dir, filename)

    with open(output_file, "w") as f:
        f.write(content)

    print(f"Wrote {output_file}")
