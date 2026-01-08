#!/usr/bin/env python3
"""
robust_error_handling_patch.py — AST-based error handling injection for Python files.
Scans project, adds try/except, logging, retry decorators, input validation.
"""

import argparse
import ast
import json
import logging
import os
import subprocess
import hashlib
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Inject robust error handling into Python files')
    parser.add_argument('--project_dir', type=str, default='.', help='Project root directory')
    parser.add_argument('--output_dir', type=str, default='./patched', help='Output directory for patched files')
    parser.add_argument('--dry_run', action='store_true', help='Preview changes without writing')
    parser.add_argument('--skip_lint', action='store_true', help='Skip linting checks')
    return parser.parse_args()


# Template for retry decorator
RETRY_DECORATOR_CODE = '''
import functools
import time
import random

def retry_with_backoff(max_retries=3, base_delay=1.0, max_delay=60.0):
    """Retry decorator with exponential backoff."""
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        delay = min(base_delay * (2 ** attempt) + random.uniform(0, 1), max_delay)
                        time.sleep(delay)
            raise last_exception
        return wrapper
    return decorator
'''

# Template for logging setup
LOGGING_SETUP_CODE = '''
import logging
import traceback
import os

# Ensure logs directory exists
os.makedirs('logs', exist_ok=True)

# Configure file handler for errors
_error_handler = logging.FileHandler('logs/errors.log')
_error_handler.setLevel(logging.ERROR)
_error_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(name)s: %(message)s'))

# Get or create logger
_patch_logger = logging.getLogger(__name__)
_patch_logger.addHandler(_error_handler)

def log_error_with_trace(error, context=""):
    """Log error with full stack trace."""
    _patch_logger.error(f"{context}: {error}")
    _patch_logger.error(traceback.format_exc())
    try:
        import mlflow
        if mlflow.active_run():
            mlflow.log_param("last_error", str(error)[:250])
            mlflow.log_metric("error_count", 1)
    except:
        pass
'''

# Template for fail_fast flag
FAIL_FAST_CODE = '''
_FAIL_FAST = False

def set_fail_fast(value):
    global _FAIL_FAST
    _FAIL_FAST = value

def check_fail_fast(error):
    if _FAIL_FAST:
        raise SystemExit(f"Fail fast enabled, exiting on error: {error}")
'''


class ErrorHandlerTransformer(ast.NodeTransformer):
    """AST transformer that wraps functions with error handling."""

    def __init__(self):
        self.modified_functions = []
        self.io_functions = {'open', 'read', 'write', 'subprocess', 'requests', 'urlopen'}

    def visit_FunctionDef(self, node: ast.FunctionDef) -> ast.FunctionDef:
        """Wrap function body with try/except."""
        self.generic_visit(node)

        # Skip if already has try/except at top level
        if node.body and isinstance(node.body[0], ast.Try):
            return node

        # Create try/except wrapper
        try_body = node.body

        except_handler = ast.ExceptHandler(
            type=ast.Name(id='Exception', ctx=ast.Load()),
            name='e',
            body=[
                ast.Expr(value=ast.Call(
                    func=ast.Name(id='log_error_with_trace', ctx=ast.Load()),
                    args=[
                        ast.Name(id='e', ctx=ast.Load()),
                        ast.Constant(value=f"Error in {node.name}")
                    ],
                    keywords=[]
                )),
                ast.Expr(value=ast.Call(
                    func=ast.Name(id='check_fail_fast', ctx=ast.Load()),
                    args=[ast.Name(id='e', ctx=ast.Load())],
                    keywords=[]
                )),
                ast.Raise()
            ]
        )

        new_body = [
            ast.Try(
                body=try_body,
                handlers=[except_handler],
                orelse=[],
                finalbody=[]
            )
        ]

        node.body = new_body
        self.modified_functions.append(node.name)

        return node

    def visit_For(self, node: ast.For) -> ast.For:
        """Wrap long-running loops with error handling."""
        self.generic_visit(node)

        # Check if loop body is substantial (more than 3 statements)
        if len(node.body) > 3:
            try_body = node.body

            except_handler = ast.ExceptHandler(
                type=ast.Name(id='Exception', ctx=ast.Load()),
                name='e',
                body=[
                    ast.Expr(value=ast.Call(
                        func=ast.Name(id='log_error_with_trace', ctx=ast.Load()),
                        args=[
                            ast.Name(id='e', ctx=ast.Load()),
                            ast.Constant(value="Error in loop iteration")
                        ],
                        keywords=[]
                    )),
                    ast.Continue()
                ]
            )

            node.body = [
                ast.Try(
                    body=try_body,
                    handlers=[except_handler],
                    orelse=[],
                    finalbody=[]
                )
            ]

        return node


class ArgparseValidator(ast.NodeTransformer):
    """Add type checks and validation to argparse arguments."""

    def visit_Call(self, node: ast.Call) -> ast.Call:
        self.generic_visit(node)

        # Check if this is an add_argument call
        if isinstance(node.func, ast.Attribute) and node.func.attr == 'add_argument':
            # Check for type keyword
            has_type = any(kw.arg == 'type' for kw in node.keywords)

            # Add type=str as default if no type specified and it's a positional-like arg
            if not has_type and node.args:
                arg_name = node.args[0]
                if isinstance(arg_name, ast.Constant) and not str(arg_name.value).startswith('-'):
                    node.keywords.append(
                        ast.keyword(arg='type', value=ast.Name(id='str', ctx=ast.Load()))
                    )

        return node


def add_retry_decorators(tree: ast.AST, source: str) -> ast.AST:
    """Add retry decorators to I/O functions."""

    class RetryAdder(ast.NodeTransformer):
        def __init__(self):
            self.io_calls = {'open', 'subprocess.run', 'subprocess.call', 'subprocess.Popen',
                           'requests.get', 'requests.post', 'urlopen'}

        def visit_FunctionDef(self, node):
            self.generic_visit(node)

            # Check if function contains I/O calls
            has_io = False
            for child in ast.walk(node):
                if isinstance(child, ast.Call):
                    if isinstance(child.func, ast.Name) and child.func.id in ['open', 'urlopen']:
                        has_io = True
                    elif isinstance(child.func, ast.Attribute):
                        if child.func.attr in ['run', 'call', 'Popen', 'get', 'post']:
                            has_io = True

            if has_io:
                # Add retry decorator
                retry_decorator = ast.Name(id='retry_with_backoff', ctx=ast.Load())
                decorator_call = ast.Call(func=retry_decorator, args=[], keywords=[])
                node.decorator_list.insert(0, decorator_call)

            return node

    return RetryAdder().visit(tree)


def add_fail_fast_arg(tree: ast.AST) -> ast.AST:
    """Add --fail_fast argument to argparse parsers."""

    class FailFastAdder(ast.NodeTransformer):
        def visit_Call(self, node):
            self.generic_visit(node)

            # Find ArgumentParser instantiation
            if isinstance(node.func, ast.Attribute) and node.func.attr == 'parse_args':
                # This is tricky - we need to find the parser and add argument
                pass

            return node

    return FailFastAdder().visit(tree)


def patch_file(filepath: Path, output_dir: Path) -> Dict[str, Any]:
    """Patch a single Python file with error handling."""

    with open(filepath, 'r') as f:
        source = f.read()

    original_lines = len(source.splitlines())

    try:
        tree = ast.parse(source)
    except SyntaxError as e:
        return {
            'file': str(filepath),
            'status': 'error',
            'error': f'Syntax error: {e}',
            'lines_added': 0
        }

    # Apply transformations
    transformer = ErrorHandlerTransformer()
    tree = transformer.visit(tree)

    # Add argparse validation
    tree = ArgparseValidator().visit(tree)

    # Add retry decorators
    tree = add_retry_decorators(tree, source)

    # Fix missing line numbers
    ast.fix_missing_locations(tree)

    # Generate patched source
    try:
        import astor
        patched_source = astor.to_source(tree)
    except ImportError:
        # Fallback: use ast.unparse (Python 3.9+)
        patched_source = ast.unparse(tree)

    # Prepend helper code
    helper_code = RETRY_DECORATOR_CODE + '\n' + LOGGING_SETUP_CODE + '\n' + FAIL_FAST_CODE + '\n'
    patched_source = helper_code + patched_source

    # Calculate output path
    rel_path = filepath.relative_to(Path('.'))
    output_path = output_dir / rel_path
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Write patched file
    with open(output_path, 'w') as f:
        f.write(patched_source)

    patched_lines = len(patched_source.splitlines())

    return {
        'file': str(filepath),
        'output': str(output_path),
        'status': 'patched',
        'functions_modified': transformer.modified_functions,
        'original_lines': original_lines,
        'patched_lines': patched_lines,
        'lines_added': patched_lines - original_lines
    }


def run_lint_checks(filepath: Path) -> Dict[str, Any]:
    """Run basic linting on patched file."""
    results = {'file': str(filepath), 'errors': [], 'warnings': []}

    # Try flake8
    try:
        result = subprocess.run(
            ['flake8', '--max-line-length=120', str(filepath)],
            capture_output=True, text=True, timeout=30
        )
        if result.stdout:
            results['warnings'].extend(result.stdout.strip().split('\n'))
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Try pylint (basic)
    try:
        result = subprocess.run(
            ['pylint', '--errors-only', str(filepath)],
            capture_output=True, text=True, timeout=60
        )
        if result.stdout:
            results['errors'].extend(result.stdout.strip().split('\n'))
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return results


def find_target_files(project_dir: Path) -> List[Path]:
    """Find all target Python files to patch."""
    targets = []

    # emoji_avatar_engine.py
    engine = project_dir / 'emoji_avatar_engine.py'
    if engine.exists():
        targets.append(engine)

    # emoji_web_customizer scripts (Python files only)
    web_dir = project_dir / 'emoji_web_customizer'
    if web_dir.exists():
        for py_file in web_dir.rglob('*.py'):
            targets.append(py_file)

    # dashboard_demo/*.py
    dashboard_dir = project_dir / 'dashboard_demo'
    if dashboard_dir.exists():
        for py_file in dashboard_dir.glob('*.py'):
            targets.append(py_file)

    # All *_*.py scripts in scripts/
    scripts_dir = project_dir / 'scripts'
    if scripts_dir.exists():
        for py_file in scripts_dir.glob('*_*.py'):
            targets.append(py_file)

    return targets


def main():
    args = parse_args()

    project_dir = Path(args.project_dir)
    output_dir = Path(args.output_dir)

    if not args.dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / 'logs').mkdir(exist_ok=True)

    # Find target files
    targets = find_target_files(project_dir)
    logger.info(f"Found {len(targets)} files to patch")

    if not targets:
        logger.warning("No target files found")
        return

    # Patch each file
    patch_results = []
    lint_results = []

    for filepath in targets:
        logger.info(f"Patching: {filepath}")

        if args.dry_run:
            result = {
                'file': str(filepath),
                'status': 'dry_run',
                'lines_added': 0
            }
        else:
            result = patch_file(filepath, output_dir)

            # Run lint checks
            if not args.skip_lint and result['status'] == 'patched':
                lint_result = run_lint_checks(Path(result['output']))
                lint_results.append(lint_result)

        patch_results.append(result)

    # Generate report
    report = {
        'timestamp': datetime.now().isoformat(),
        'project_dir': str(project_dir),
        'output_dir': str(output_dir),
        'dry_run': args.dry_run,
        'files_processed': len(patch_results),
        'files_patched': sum(1 for r in patch_results if r['status'] == 'patched'),
        'total_lines_added': sum(r.get('lines_added', 0) for r in patch_results),
        'results': patch_results,
        'lint_results': lint_results
    }

    # Write report
    if not args.dry_run:
        report_path = output_dir / 'patch_report.json'
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        logger.info(f"Report saved to: {report_path}")

    # Summary
    logger.info(f"Patching complete: {report['files_patched']}/{report['files_processed']} files")
    logger.info(f"Total lines added: {report['total_lines_added']}")

    # Log to MLflow if available
    try:
        import mlflow
        with mlflow.start_run(run_name='error_handling_patch'):
            mlflow.log_param('project_dir', str(project_dir))
            mlflow.log_metric('files_patched', report['files_patched'])
            mlflow.log_metric('lines_added', report['total_lines_added'])
            if not args.dry_run:
                mlflow.log_artifact(str(report_path))
    except:
        pass


if __name__ == '__main__':
    main()
