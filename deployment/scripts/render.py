# Takes variable list and replaces template variables in index order
import sys, os, argparse

def main(input_file, output_file, variable_list):
    if input_file == '' or output_file == '':
       sys.stdout.write('Must provide input and output files.')
       sys.exit(0)
    if not os.path.isfile(input_file):
       sys.stdout.write(f'No file located at {input_file}')
       sys.exit(0)
    template_string = ''
    sys.stdout.write(f'Reading {input_file}...')
    with open(input_file, 'r') as f:
       template_string = f.read()
    sys.stdout.write(f'Parsing variables...')
    for idx, variable in enumerate(variable_list):
       template_string = template_string.replace(f'%%#{idx}#%%', variable)
    sys.stdout.write(f'Writing {output_file}...')
    with open(output_file, 'w+') as f:
       f.write(template_string)

def list_of_strings(arg):
   return arg.split(',')


parser = argparse.ArgumentParser()
parser.add_argument('-i', '--input_file')
parser.add_argument('-o', '--output_file')
parser.add_argument('-l', '--list', type=list_of_strings)
args = parser.parse_args()
main(args.input_file, args.output_file, args.list)