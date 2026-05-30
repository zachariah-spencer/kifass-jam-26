class TextCorruptor
  def initialize text
    @text = text
    @order = []
    text.length.times do |index|
      next if text[index] == " "

      insert_at = @order.length == 0 ? 0 : rand(@order.length + 1)
      @order.insert(insert_at, index)
    end
    @scrambled_text = text.dup
    @scrambled_at = nil
  end

  def text elapsed
    scramble_count = elapsed.idiv(Game::SACRIFICE_SCRAMBLE_INTERVAL).clamp(0, @order.length)
    scramble_tick = elapsed.idiv(Game::SACRIFICE_SCRAMBLE_INTERVAL)
    return @scrambled_text if @scrambled_at == scramble_tick

    scramble_count.times do |index|
      word_index = @order[index]
      @scrambled_text[word_index] = Game::SACRIFICE_SCRAMBLE_SYMBOLS[rand(Game::SACRIFICE_SCRAMBLE_SYMBOLS.length)]
    end
    @scrambled_at = scramble_tick
    @scrambled_text
  end
end
