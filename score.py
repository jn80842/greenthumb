import argparse
import kenlm

def find_perplexity(model,test_data):
  word_total = 0
  score_total = 0
  for sentence in test_data:
    words = len(sentence.split()) + 1 # For </s>
    word_total += words
    score = model.score(sentence)
    score_total += score
  return 10.0**(-score_total / word_total)

def get_parser():
  parser = argparse.ArgumentParser()
  parser.add_argument("input")
  # parser.add_argument("arpa",help='trained model')
  # parser.add_argument("test_filename",help='name of file containing test data')
  return parser


if __name__ == '__main__':
  parser = get_parser()
  config = parser.parse_args()
  model = kenlm.Model("/Users/mpu/mapl/c_programs/assembly/processed_total_suite.binary")
  input_data = config.input
  input_data = input_data.split("\n")
  print(find_perplexity(model,input_data))
