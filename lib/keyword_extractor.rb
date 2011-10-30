require 'bundler/setup'

require 'matrix'
require 'core_ext/matrix'

require 'engtagger'
require 'stemmer'

require 'keyword_extractor/word'
require 'keyword_extractor/graph'
require 'keyword_extractor/graph_printer'
require 'keyword_extractor/page_rank'

module KeywordExtractor
  class << self

    def calculate_word_frequencies(words)
      word_counts = Hash.new(0)
      words.each { |word| word_counts[word] += 1 }
      word_counts
    end

    def calculate_cooccurrences(words)
      cooccurrences = Hash.new(0)

      ngrams(words, 4) do |ngram|
        [
          [ngram[0], ngram[1]].sort,
          [ngram[0], ngram[2]].sort,
          [ngram[0], ngram[3]].sort,
          [ngram[1], ngram[2]].sort,
          [ngram[1], ngram[3]].sort,
          [ngram[2], ngram[3]].sort
        ].uniq.each do |cooccurrence|
          cooccurrences[cooccurrence] += 1
        end
      end

      cooccurrences
    end
    
    def calculate_most_important_words(words, count = 5)
      cooccurrences = calculate_cooccurrences(words)
      
      cooccurrences.delete_if do |cooccurrence| 
        not (cooccurrence.first.noun_or_adjective? and cooccurrence.last.noun_or_adjective?)
      end
      
      word_list = Set.new
      cooccurrences.each do |cooccurrence, count|
        word_list << cooccurrence.first
        word_list << cooccurrence.last
      end
      word_list = word_list.to_a
      
      graph = Graph.new(word_list.count, false)
      word_list.each_with_index do |word, index|
        graph.label(index, word.stemmed)
      end
      
      cooccurrences.each do |cooccurrence, count|
        graph[cooccurrence.first.stemmed, cooccurrence.last.stemmed] = count
      end
      
      lmi_graph = graph.to_lmi_graph
      ranks     = PageRank.calculate(lmi_graph, count)
      
      word_list.each_with_index do |word, index|
        word.rank = ranks[index]
      end
      
      word_list.sort { |a, b| (a.rank <=> b.rank) * -1 }[0 ... count]
    end
    
    def extract_most_important_words(text, count = 5)
      words = tag(text)
      calculate_most_important_words(words, count)
    end
    
    def print_cooccurrence_graph(text)
      words = tag(text)
      
      cooccurrences = calculate_cooccurrences(words)
      
      cooccurrences.delete_if do |cooccurrence| 
        not (cooccurrence.first.noun_or_adjective? and cooccurrence.last.noun_or_adjective?)
      end
      
      word_list = Set.new
      cooccurrences.each do |cooccurrence, count|
        word_list << cooccurrence.first
        word_list << cooccurrence.last
      end
      word_list = word_list.to_a
      
      graph = Graph.new(word_list.count, false)
      word_list.each_with_index do |word, index|
        graph.label(index, word.stemmed)
      end
      
      cooccurrences.each do |cooccurrence, count|
        graph[cooccurrence.first.stemmed, cooccurrence.last.stemmed] = count
      end
      
      lmi_graph = graph.to_lmi_graph
      ranks     = PageRank.calculate(lmi_graph, 10)
      
      word_list.each_with_index do |word, index|
        word.rank = ranks[index]
      end
      
      GraphPrinter.print(graph)
    end

    private

      def ngrams(words, size = 1)
        0.upto(words.length - size) do |index|
          yield words[index ... index + size]
        end
      end
      
      def tag(text)
        tagger = EngTagger.new

        tagger.get_readable(text).split(' ').map do |w|
          Word.from_string(w)
        end
      end
      
  end
end