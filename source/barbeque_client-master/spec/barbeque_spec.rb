describe BarbequeClient do
  describe '.configure' do
    it 'updates .config' do
      expect {
        BarbequeClient.configure do |c|
          c.application   = 'blog'
          c.default_queue = 'blog-default'
          c.endpoint      = 'https://barbeque.example.com'
        end
      }.to change {
        %i[
          application
          default_queue
          endpoint
        ].map { |attribute| BarbequeClient.config.public_send(attribute) }
      }.from(
        [nil, 'default', nil]
      ).to(
        ['blog', 'blog-default', 'https://barbeque.example.com']
      )
    end
  end
end
