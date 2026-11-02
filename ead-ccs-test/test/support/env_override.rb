# Runs a block with environment variables set (a nil value unsets), then puts them back. The tests that use it run in one process
# at a time, so the change is not seen by another test.
module EnvOverride
  def with_env(changes)
    saved = changes.keys.index_with { |name| ENV.fetch(name, nil) }
    changes.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value.to_s }
    yield
  ensure
    saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end
end
