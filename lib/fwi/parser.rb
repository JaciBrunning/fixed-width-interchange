class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
        self.merge(second.to_h, &merger)
    end
end

module FWI
    class Parser
        TYPE_MAP = {
            "float64"   => :float64,
            "float32"   => :float32,
            "u64"       => :u64,
            "u32"       => :u32,
            "u16"       => :u16,
            "u8"        => :u8,
            "i64"       => :i64,
            "i32"       => :i32,
            "i16"       => :i16,
            "i8"        => :i8,
            "string"    => :string,
            "bool"      => :bool,

            "blank"     => :blank,

            "float"     => :float32,
            "double"    => :float64,
            "ulong"     => :u64,
            "long"      => :i64,
            "uint"      => :u32,
            "int"       => :i32,
            "ushort"    => :u16,
            "short"     => :i16,
            "char"      => :i8,
            "uchar"     => :u8,
            "byte"      => :i8,
            "ubyte"     => :u8,
            "boolean"   => :bool,
            "bit"       => :bool
        };

        TYPE_SIZES = {
            :float64 => 8,
            :u64 => 8,
            :i64 => 8,

            :float32 => 4,
            :u32 => 4,
            :i32 => 4,

            :u16 => 2,
            :i16 => 2,

            :u8 => 1,
            :i8 => 1
        };
        
        # Do the initial parsing on the file
        def lex src_file, src_dir
            src = File.read(File.join(src_dir, src_file))
            hash = { 
                :members => {}, 
                :files => { 
                    src_file => { 
                        :imports => [],
                        :enums => [],
                        :blocks => []
                    } 
                }, 
                :block_order => [] 
            }
            file = hash[:files][src_file]

            _blevel = []
            hashobj = lambda do
                hr = hash
                _blevel.select { |n| n[:type] == :namespace }.each do |ns|
                    hr = hr[:members][ns[:name]]
                end
                hr
            end

            namespacedive = lambda do |fqn|
                hr = hash
                comp = fqn.split("::")
                _blevel.select { |x| x[:type] == :namespace }.each do |b|
                    return nil if hr.nil?
                    hr = hr[:members][b[:name]]
                end
                comp.each do |c|
                    return nil if hr.nil?
                    hr = hr[:members][c]
                end
                hr
            end

            rootdive = lambda do |fqn|
                hr = hash
                comp = fqn.split("::")
                comp.each do |a|
                    return nil if hr.nil?
                    hr = hr[:members][a]
                end
                hr
            end

            current_fqn = lambda do
                _blevel.select { |n| n[:type] == :namespace }.map { |n| n[:name] }.join("::")
            end

            findtype = lambda do |tn|
                return tn unless rootdive[tn].nil?
                unless namespacedive[tn].nil?
                    return [current_fqn[], tn].join("::")
                end
                usings = _blevel.each_index.map { |x| Hash[x, _blevel[x]] if _blevel[x][:type] == :using }.reject(&:nil?)
                usings.size.times do |time|
                    afqn = [usings.first(time + 1).map { |x| x.values[0][:name] }, tn].join("::")
                    return afqn unless rootdive[afqn].nil?
                    return [current_fqn[], afqn].join("::") unless namespacedive[afqn].nil?
                end
                nil
            end

            _enumidx = 0

            src.each_line.map(&:strip).reject { |l| l.start_with?("//") || l.start_with?("#") }.each do |line|
                tok = line.split(/\s+/).reject(&:empty?)
                unless _blevel.empty? || tok[0] == "}"
                    cur = _blevel.last
                    b_name = cur[:name]
                    b_type = cur[:type]
                    h = hashobj[][:members][b_name]

                    if b_type == :block
                        type, vals = line.split(/\s+/, 2)

                        next if vals.nil?
                        vals.split(/\s*,\s*/).each do |splitcomma|
                            name, *attrib = splitcomma.split(/\s+/).reject(&:empty?)
                            array_match = /(.+)\[([0-9]+)\]/.match(name)
                            arrlen = 1

                            unless array_match.nil?
                                name = array_match[1]
                                arrlen = array_match[2].to_i
                            end

                            type_s = TYPE_MAP[type]
                            m = { :type => type_s, :name => name, :original_type => type }
                            m[:attributes] = attrib
                            m[:attribute_map] = Hash[attrib.select { |x| x.is_a?(String) && x.include?("=") }.map { |x| x.split(/\s*=\s*/, 2) }]

                            if m[:type].nil?
                                fqn = findtype[type]
                                throw "Can't find type: #{type}" if fqn.nil?
                                m[:type] = :reference
                                m[:element_name] = fqn
                                m[:element_type] = rootdive[fqn][:type]

                                spl = fqn.split("::")
                                spl_cu = current_fqn[].split("::")

                                min = spl - spl_cu
                                if min.empty?
                                    m[:reltype] = fqn
                                else
                                    m[:reltype] = min.join("::")
                                end
                            end

                            unless arrlen == 1
                                m[:array] = arrlen
                            end
                            h[:members] << m
                        end
                    elsif b_type == :enum
                        line.split(",").each do |ln|
                            a, b, c = ln.split(/\s+/).reject(&:empty?)

                            if !b.nil? && b == "="
                                _enumidx = c.to_i
                            end
                            h[:members] << { :name => a, :val => _enumidx}
                            _enumidx = _enumidx + 1
                        end
                    end
                end
                
                if tok[0] == "}"
                    _blevel.pop
                elsif tok[0] == "namespace"
                    if tok[2] == "{"
                        hashobj[][:members][tok[1]] = { :type => :namespace, :members => {} }
                        _blevel << { :type => :namespace, :name => tok[1] }
                    else
                        tok[1].split("::").each do |ns|
                            hashobj[][:members][ns] = { :type => :namespace, :members => {} }
                            _blevel << { :type => :namespace, :name => ns }
                        end
                    end
                elsif tok[0] == "block"
                    cur = current_fqn[]
                    fulltype = tok[1]
                    fulltype = cur + "::" + tok[1] unless cur.empty?

                    hashobj[][:members][tok[1]] = { 
                        :type => :block, 
                        :members => [], 
                        :file => src_file,
                        :fulltype => fulltype
                    }

                    # Block Order is used by the bitmap generator to decide what order to process block sizes
                    # and references in. This means that declaration order matters
                    hash[:block_order] << fulltype
                    file[:blocks] << fulltype

                    _blevel << { :type => :block, :name => tok[1] }
                elsif tok[0] == "enum"
                    cur = current_fqn[]
                    fulltype = tok[1]
                    fulltype = cur + "::" + tok[1] unless cur.empty?

                    hashobj[][:members][tok[1]] = { 
                        :type => :enum, 
                        :members => [], 
                        :file => src_file,
                        :fulltype => fulltype
                    }
                    _enumidx = 0
                    _blevel << { :type => :enum, :name => tok[1] }

                    file[:enums] << fulltype
                elsif tok[0] == "using" && tok[1] == "namespace"
                    if tok[3] == "{"
                        _blevel << { :type => :using, :name => tok[2] }
                    else
                        tok[2].split("::").each do |ns|
                            _blevel << { :type => :using, :name => ns }
                        end
                    end
                elsif tok[0] == "import"
                    file[:imports] << tok[1]
                    hash = hash.deep_merge(lex(tok[1], src_dir))
                end
            end
            hash
        end

        def bitmap lex
            lex[:block_order].each do |block_name|
                block = lex
                block_name.split("::").each { |x| block = block[:members][x] }
                
                bools, nonbools = block[:members].partition { |el| el[:type] == :bool && el[:array].nil? }
                idx = 0

                bools.each_slice(8) do |byte|
                    byte.each_with_index do |bitvalue, i|
                        bitvalue[:bit_index] = i
                        bitvalue[:index] = idx
                    end
                    idx += 1
                end

                nonbools.each do |member|
                    t = member[:type]
                    n = member[:name]

                    arraysize = 1
                    arraysize = member[:array] unless member[:array].nil?

                    if t == :bool
                        # It must be a boolean array.
                        total_size = (arraysize / 8.to_f).ceil
                        member[:index] = idx
                        member[:size] = total_size
                        idx += total_size
                    elsif t == :blank
                        idx += arraysize
                    elsif t == :string
                        typesize = member[:attributes][0].to_i
                        len = typesize * arraysize
                        member[:index] = idx
                        member[:size] = len
                        member[:typesize] = typesize
                        idx += len
                    elsif t == :reference
                        if member[:element_type] == :block
                            referenced = lex
                            member[:element_name].split("::").each { |a| referenced = referenced[:members][a] }
                            
                            size = referenced[:size] * arraysize
                            member[:size] = size
                            member[:index] = idx
                            member[:typesize] = referenced[:size]
                            idx += size
                        elsif member[:element_type] == :enum
                            member[:size] = arraysize
                            member[:typesize] = 1
                            member[:index] = idx
                            idx += arraysize
                        end
                    else
                        size = TYPE_SIZES[t] * arraysize
                        member[:size] = size
                        member[:index] = idx
                        member[:typesize] = TYPE_SIZES[t]
                        idx += TYPE_SIZES[t] 
                    end
                end
                
                # Remove :blank types
                block[:members].each_index.select { |i| block[:members][i][:type] == :blank }.each { |x| block[:members].delete_at(x) }
                
                # Final Size
                block[:size] = idx
            end
            lex
        end
    end
end