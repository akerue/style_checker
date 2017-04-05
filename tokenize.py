# _*_coding:utf-8_*_

from log_tool import generate_logger

logger = generate_logger(__file__)

import os
import argparse

from pygments.lexers.ruby import RubyLexer
from pygments.token import is_token_subtype

from pygments.token import Comment, Literal, String, Number


def find_all_files(directory):
    for root, dirs, files in os.walk(directory):
        yield root
        for file in files:
            yield os.path.join(root, file)


def replace_special_char(token):
    # 空白と改行を特別な文字に変換する
    token = token.replace(" ", "SPACE ").replace("\n", "NEWLINE ")
    # 空白を最後に一つだけつけたいので、SPACEやNEWLINEでついた空白を
    # 除いた後、空白を最後につける
    return token.rstrip() + " "


def main(source, output):
    program_path_list = find_all_files(source)
    program_path_list = filter(lambda p: os.path.splitext(p)[1] == ".rb",
                               program_path_list)

    lexer = RubyLexer()
    token_streams = []

    for program_path in program_path_list:
        with open(program_path, "r") as f:
            token_streams.append(lexer.get_tokens(f.read()))

    # TODO: タグ付きにするともっと精度よくなりそう
    # 今回はタグなしで

    for stream in token_streams:
        for token_data in stream:
            token_type = token_data[0]
            token = token_data[-1]

            if is_token_subtype(token_type, Comment):
                # コメントは今回は無視
                continue
            elif is_token_subtype(token_type, Literal):
                arranged_token = "LITERAL"
            elif is_token_subtype(token_type, String):
                arranged_token = "STRING"
            elif is_token_subtype(token_type, Number):
                arranged_token = "NUMBER"
            else:
                arranged_token = replace_special_char(token)

            output.write(arranged_token.encode("utf-8"))
        output.write("\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--source", required=True, type=str)
    parser.add_argument("-o", "--output", required=True, type=argparse.FileType("w"))
    args = parser.parse_args()

    try:
        main(args.source, args.output)
    except Exception as e:
        logger.exception(e.args)

