# Stub for puppetdb_query function - returns empty array when no PuppetDB is available
Puppet::Functions.create_function(:puppetdb_query) do
  dispatch :query do
    param 'String', :pql
    return_type 'Array'
  end

  def query(pql)
    Puppet.warning("puppetdb_query stub: no PuppetDB available, returning empty array")
    []
  end
end
