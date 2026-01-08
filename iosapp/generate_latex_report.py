#!/usr/bin/env python3
"""
generate_latex_report.py — Generate LaTeX progress report.
"""

import argparse
import pandas as pd
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--metrics_csv', type=str, required=True)
    parser.add_argument('--template', type=str, default='')
    parser.add_argument('--output_tex', type=str, required=True)
    parser.add_argument('--include_plots', action='store_true')
    parser.add_argument('--include_tables', action='store_true')
    args = parser.parse_args()

    df = pd.read_csv(args.metrics_csv)

    latex = r"""
\documentclass{article}
\usepackage{booktabs}
\usepackage{graphicx}
\title{Komal Extended Progress Report}
\author{ML Pipeline}
\date{\today}
\begin{document}
\maketitle

\section{Summary}
Total experiments: """ + str(len(df)) + r"""

\section{Results}
"""

    if args.include_tables and len(df) > 0:
        latex += r"""
\begin{table}[h]
\centering
\begin{tabular}{lcc}
\toprule
Source & Count & Files \\
\midrule
"""
        for source in df['source'].unique() if 'source' in df.columns else ['all']:
            count = len(df[df['source'] == source]) if 'source' in df.columns else len(df)
            latex += f"{source} & {count} & - \\\\\n"

        latex += r"""
\bottomrule
\end{tabular}
\caption{Experiment Summary}
\end{table}
"""

    latex += r"""
\end{document}
"""

    output_path = Path(args.output_tex)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w') as f:
        f.write(latex)

    print(f"generated {output_path}")


if __name__ == '__main__':
    main()
