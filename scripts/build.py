import sys
import os
import subprocess
import argparse

units = []
incs = []
macros = {}
unresolved = set()
modules = set()

SPACES = ' \t\v\f\r\n'
EOL = '\r\n'
TOKEN_SPLIT = SPACES + '+-*/()=&|~%,;[]:{}<>\''
GENERATOR = sys.argv[0]

def scan_files(path, ext):
    ret = []
    for file in os.listdir(path):
        if file.endswith(ext):
            ret.append('%s/%s' % (path, file))
    return ret

def skip_space(code, split, start):
    t = code[start:]
    for p, c in enumerate(t):
        if c[0] not in split:
            return start + p
    return start
    
def skip_token(code, ends, start):
    t = code[start:]
    for p, c in enumerate(t):
        if c[0] in ends:
            return start + p
    return start + len(t)

def next_eol(line, offset):
    for i in range(offset, len(line)):
        if line[i] in EOL:
            return i
    return len(line)

def strip_comments(code):
    i = 0
    lc = len(code)
    ret = []
    while i < lc:
        if code[i] == '/' and code[i+1] == '/':
            i = next_eol(code, i+2)
            continue
        elif code[i] == '/' and code[i+1] == '*':
            match = False
            for j in range(i+2, len(code)):
                if code[j] == '*' and code[j+1] == '/':
                    i = j + 2;
                    match = True
                    break
            if not match:
                print('Comment /* and */ mismatch!')
                exit(1)
            continue
        ret.append(code[i])
        i = i + 1
    return ''.join(ret)

def apply_macro(lines, fn):
    global macros
    global incs
    buf = []
    changed = False
    
    def get_param(line, pos_directive):
        pos_tk_start = skip_space(line, SPACES, pos_directive + 7)
        pos_tk_end = skip_token(line, SPACES, pos_tk_start)
        return pos_tk_end, line[pos_tk_start:pos_tk_end]
    
    def is_if(t):
        return ((len(t) > 6 and t[0:6] == '`ifdef') or (len(t) > 7 and t[0:7] == '`ifndef'))
    
    li = len(lines)
    i = 0
    if_stack_depth = 0
    
    while i < li:
        line = lines[i]
        pos_directive = skip_space(line, SPACES, 0)
        t = line[pos_directive:]
        
        #`include
        if (len(t) > 8 and t[0:8] == '`include'):
            f = t[8:].strip(SPACES+'"')
            for d in incs:
                fname = '%s/%s' % (d, f)
                if os.path.isfile(fname):
                    with open(fname, 'r') as fp_src:
                        buf.append(strip_comments(fp_src.read()))
                        changed = True
                    break
            else:
                print('%ERROR Can''t find file "%s"' % f)
                print('I have found in the following directories:')
                for d in incs:
                    print('\t%s' % d)
            
        # `define
        elif (len(t) > 7 and t[0:7] == '`define'):
            pos_tk_end, token = get_param(line, pos_directive)
            pos_val_start = skip_space(line, SPACES, pos_tk_end)
            value = line[pos_val_start:]
            if token in macros:
                print('%%WARNING %s: Macro "%s" is overriden' % (fn ,token))
            macros[token] = {'value': value}
            
        # `ifdef `ifndef
        elif (is_if(t)):
            if_stack_depth = if_stack_depth + 1
            _, token = get_param(line, pos_directive)
            
            # Resolve the position of `if/`else/`endif
            this_if_stack_depth = if_stack_depth
            lineno_endif = -1
            lineno_else = -1
            for j in range(i+1, li):
                line = lines[j]
                pos_directive = skip_space(line, SPACES, 0)
                d = line[pos_directive:]
                if (len(d) >= 6 and d[0:6] == '`endif'):
                    if_stack_depth = if_stack_depth - 1
                    if if_stack_depth + 1 == this_if_stack_depth: # `if..`endif pair matched
                        lineno_endif = j
                        break
                elif (is_if(d)):
                    if_stack_depth = if_stack_depth + 1
                elif (len(d) >= 5 and d[0:5] == '`else'):
                    if if_stack_depth == this_if_stack_depth:
                        if lineno_else != -1:
                            print("%ERROR %s Line %d: Multiple else branches" % (fn, i+1))
                            exit(1)
                        lineno_else = j;
            if lineno_endif == -1:
                print('%%ERROR %s Line %d:`if...`endif mismatch!' % (fn, i+1))
                exit(1)

            if (t[3] != 'n' and token not in macros) or \
                (t[3] == 'n' and token in macros):
                # The condition unmet
                # Skip `if..`else/`endif block   
                if lineno_else != -1:
                    buf.extend(map(lambda x: x+'\n', lines[lineno_else+1:lineno_endif]))
                    changed = True
            else:
                # The condition met
                # Skip `else...`endif block if any
                if lineno_else != -1:
                    buf.extend(map(lambda x: x+'\n', lines[i+1:lineno_else]))
                else:
                    buf.extend(map(lambda x: x+'\n', lines[i+1:lineno_endif]))
                changed = True
            
            i = lineno_endif
        
        # `endif
        elif (len(t) >= 6 and t[0:6] == '`endif'):
            if_stack_depth = if_stack_depth - 1
            if if_stack_depth < 0:
                print('%%ERROR %s Line %d: `if...`endif mismatch 2!' % (fn, i+1))
                exit(1)
        
        # `undef
        elif (len(t) > 6 and t[0:6] == '`undef'):
            _, token = get_param(line, pos_directive)
            if token in macros:
                macros.pop(token)

        else:
            k = 0
            lk = len(line)
            while k < lk:
                if (line[k] == '`'):
                    pos_tk_start = k + 1
                    pos_tk_end = skip_token(line, TOKEN_SPLIT, pos_tk_start)
                    token = line[pos_tk_start:pos_tk_end]
                    unresolv_dict = (fn, token)
                    if token in macros:
                        # Macro replacement
                        buf.append(macros[token]['value'])
                        changed = True
                        
                        if unresolv_dict in unresolved:
                            unresolved.discard(unresolv_dict)
                    else:
                        unresolved.add(unresolv_dict)
                        buf.append('`'+token) # Resolve the token in the next iteration
                    k = pos_tk_end
                    continue
                else:
                    buf.append(line[k])
                k = k + 1
                
            buf.append('\n')
        
        i = i + 1
    return changed, ''.join(buf)

def preprocess(unit):
    # Iterate n+1 rounds
    while True:
        changed, unit['code'] = apply_macro(unit['code'].splitlines(), unit['file'])
        if not changed: break

def strip_empty_lines(code):
    ret = []
    for ln in code.splitlines():
        if len(ln.strip(SPACES)):
            ret.append(ln)
            ret.append('\n')
    return ''.join(ret)
    
def define_macro(token, value):
    global macros
    macros[token] = value

def resolve_module(code):
    global modules
    pos = 0
    for line in code.splitlines():
        pos_token_start = skip_space(line, SPACES, 0)
        pos_token_end = skip_token(line, TOKEN_SPLIT, pos_token_start)
        token = line[pos_token_start:pos_token_end]
        if (token == 'module'):
            pos_name_start = skip_space(code, SPACES, pos + pos_token_end)
            pos_name_end = skip_token(code, TOKEN_SPLIT, pos_name_start)
            mname = code[pos_name_start:pos_name_end]
            print('--------------- Found module %s' % mname)
            modules.add(mname)
        pos = pos + len(line) + 1 # plus an EOL

def add_module_prefix(code, prefix, toplevel):
    lc = len(code)
    buf = []
    pos = 0
    for line in code.splitlines():
        npos = pos + len(line) + 1 # plus an EOL
        pos_token_start = skip_space(line, SPACES, 0)
        pos_token_end = skip_token(line, TOKEN_SPLIT, pos_token_start)
        token = line[pos_token_start:pos_token_end]

        # Match module <rname>
        if (token == 'module'):
            pos_name_start = skip_space(code, SPACES, pos + pos_token_end)
            pos_name_end = skip_token(code, TOKEN_SPLIT, pos_name_start)
            rname = code[pos_name_start:pos_name_end]
            if rname in modules and rname != toplevel:
                # Append prefix for module declaration name
                buf.append(code[pos:pos_name_start])
                buf.append(prefix)
                buf.append(code[pos_name_start:npos])
            else:
                buf.append(code[pos:npos])

        # Match "<module_name> #(" or "<module_name> <inst_name> ("
        elif (token in modules and token != toplevel):
            addprefix = False
            # Test if it's a module instantiation
            pos_param_start = skip_space(code, SPACES, pos + pos_token_end)
            if (code[pos_param_start]=='#'):
                pos_param_start = skip_space(code, SPACES, pos_param_start+1)
                if (code[pos_param_start] == '('):
                    addprefix = True
            else:
                pos_name_end = skip_token(code, TOKEN_SPLIT, pos_param_start)
                pos_ports_start = skip_space(code, SPACES, pos_name_end)
                if (code[pos_ports_start]=='('):
                    addprefix = True
 
            if (addprefix):
                # Append prefix for module instance name
                buf.append(code[pos:pos+pos_token_start])
                buf.append(prefix)
                buf.append(code[pos+pos_token_start:npos])
            else:
                buf.append(code[pos:npos])
        
        else:
            buf.append(code[pos:npos])

        pos = npos

    return ''.join(buf)


parser = argparse.ArgumentParser(description="Preprocess CPU RTL design")
parser.add_argument('--project-dir', '-d', required=True, type=str, help='Project root path')
parser.add_argument('--input-dir', '-s', required=False, type=str, nargs='+', help='Target directory (Scan all *.v files)')
parser.add_argument('--input-file', '-c', required=False, type=str, nargs='+', help='Target files')
parser.add_argument('--inc', '-I', required=True, type=str, nargs='+', help='Include path')
parser.add_argument('--toplevel', '-t', required=True, type=str, help='Toplevel module name')
parser.add_argument('--prefix', '-p', required=True, type=str, help='Module name prefix')
parser.add_argument('--output', '-o', required=True, type=str, help='Output file name')

args = parser.parse_args()

PRJ_ROOT = args.project_dir
incs.extend(args.inc)
PREFIX = args.prefix
TOPLEVEL = args.toplevel
TARGET = args.output

SRC = []
if args.input_dir is not None:
    for tgt in args.input_dir:
        SRC.extend(scan_files(tgt, '.v'))
if args.input_file is not None:
    SRC.extend(args.input_file)

if len(SRC) == 0:
    print('Needed at least one input file!')
    exit(1)

# Built-in macros
define_macro('SYNTHESIS', '')

#
# PASS 1: Resolve compiling units and strip comments
#
for src_file in SRC:
    with open(src_file, 'r') as fp_src:
        print('Reading "%s"' % src_file)
        units.append({'file': src_file,
                        'code': strip_comments(fp_src.read())});

#
# PASS 2..2+n: (iterate n+1 rounds) Apply macros
#
for i, u in enumerate(units):
    preprocess(u)
    
if len(unresolved):
    for file,token in unresolved:
        print('%%ERROR %s: Macro "%s" undefined!' % (file, token))
    exit(1)
    
#
# PASS n+3 Strip empty lines
#
buf = []
for u in units:
    buf.append(u['code'])
    buf.append('\n')
buf = strip_empty_lines(''.join(buf))

#
# PASS n+4 Add prefix for all modules
#
resolve_module(buf)
buf = add_module_prefix(buf, PREFIX, TOPLEVEL)

# Generate the target

def get_git_rev_hash(rootpath):
    if os.path.isdir('%s/.git' % rootpath):
        return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd = rootpath).decode()
    return None

rev_hash = get_git_rev_hash(PRJ_ROOT)
banner = '// Generator : %s\n// Toplevel : %s\n// Prefix : %s' % (GENERATOR, TOPLEVEL, PREFIX)
if rev_hash is not None:
    banner += '\n// Git hash  : %s\n' % rev_hash

print('Generating "%s"' % TARGET)
with open(TARGET, 'w') as fp:
    fp.write(banner)
    fp.write(buf)

print('Done')
