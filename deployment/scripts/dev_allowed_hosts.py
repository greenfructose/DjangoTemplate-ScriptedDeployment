import sys, os, argparse


def main(project_name, host_list):
    new_settings = ''
    hosts_string = "ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '0.0.0.0', "
    for host in host_list:
        hosts_string = hosts_string + f"'{host}', "
    hosts_string = hosts_string.strip() + ']'
    with open(f'./{project_name}/settings.py', 'r') as f:
        new_settings = f.read().replace("ALLOWED_HOSTS = []", hosts_string)
    with open(f'./{project_name}/settings.py', 'w') as f:
        f.write(new_settings)
    
def list_of_strings(arg):
   return arg.split(',')

parser = argparse.ArgumentParser()
parser.add_argument('-p', '--project_name')
parser.add_argument('-l', '--host_list', type=list_of_strings)
args = parser.parse_args()
main(args.project_name, args.host_list)