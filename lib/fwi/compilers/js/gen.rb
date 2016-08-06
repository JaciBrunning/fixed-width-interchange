module FWI
module Generator
    class JS
        def append buffer, indent, string
            string.split(/\n/).each { |y| buffer << ("\t" * indent) + y + "\n" }
        end

        def _func_util obj, member, mode
            type = member[:type]
            internal_type = type.to_s
            internal_type = "child" if type == :reference && member[:element_type] == :block
            internal_type = "u8" if type == :reference && member[:element_type] == :enum
            
            param = member[:array].nil? ? "" : "index#{mode == :setter ? ', ' : ''}"
            custom_getter = member[:attribute_map]["getter"]
            custom_setter = member[:attribute_map]["setter"]
            custom_length = member[:attribute_map]["length_func"]

            func_name = nil
            func_sig = nil
            if mode == :setter
                func_name = custom_setter.nil? ? "set_#{member[:name]}" : custom_setter
                func_sig = "function(#{param}value) {"
            elsif mode == :getter
                func_name = custom_getter.nil? ? "get_#{member[:name]}" : custom_getter
                func_sig = "function(#{param}) {"
            elsif mode == :length
                func_name = custom_length.nil? ? "#{member[:name]}_length" : custom_length
                func_sig = "function(#{param}) {"
            end

            index = member[:index]
            index = "#{index} + (#{member[:typesize]} * index)" unless member[:array].nil?
            { :internal_type => internal_type, :index => index, :func_name => func_name, :func_sig => func_sig }
        end

        def write_getter obj, member, str, indent
            return "" if member[:attributes].include? "no-getter"
            util = _func_util(obj, member, :getter)

            fullfunc = obj + ".prototype." + util[:func_name] + " = " + util[:func_sig]
            append(str, indent, fullfunc)
            type = member[:type]
            if type == :reference && member[:element_type] == :block
                type = member[:element_name].gsub("::", ".")
                append(str, indent + 1, "return this.get_child(#{type}, #{util[:index]});")
            elsif type == :bool
                if member[:array].nil?
                    append(str, indent + 1, "return this.get_bool(#{util[:index]}, #{member[:bit_index]});")
                else
                    append(str, indent + 1, "return this.get_bool(#{member[:index]} + index / 8, index % 8, value);")
                end
            else
                append(str, indent + 1, "return this.get_#{util[:internal_type]}(#{util[:index]});")
            end
            append(str, indent, "};")
        end

        def write_setter obj, member, str, indent
            return "" if member[:attributes].include? "no-setter"
            util = _func_util(obj, member, :setter)
            
            fullfunc = obj + ".prototype." + util[:func_name] + " = " + util[:func_sig]
            append(str, indent, fullfunc)
            type = member[:type]
            if type == :bool
                if member[:array].nil?
                    append(str, indent + 1, "this.set_bool(#{util[:index]}, #{member[:bit_index]}, value);")
                else
                    append(str, indent + 1, "this.set_bool(#{member[:index]} + index / 8, index % 8, value);")
                end
            else
                append(str, indent + 1, "this.set_#{util[:internal_type]}(#{util[:index]}, value);")
            end
            append(str, indent, "};")
        end
        
        def write_length obj, member, str, indent
            return "" if member[:attributes].include? "no-len"
            util = _func_util(obj, member, :length)

            fullfunc = obj + ".prototype." + util[:func_name] + " = " + util[:func_sig]
            append(str, indent, fullfunc)
            append(str, indent + 1, "return #{member[:size]};")
            append(str, indent, "};")
        end

        def gen_prototype obj, member, str, indent
            write_getter obj, member, str, indent
            if member[:type] == :reference
                if member[:element_type] == :enum
                    write_setter obj, member, str, indent
                end
            else
                write_setter obj, member, str, indent
                write_length(obj, member, str, indent)if member[:type] == :string
            end
        end

        def gen_for_ns parent, name, ns, str, indent
            is_root = name == "<root>"
            has_parent = parent != "<root>"

            fqn_ns = name
            fqn_ns = parent + "." + fqn_ns if has_parent

            unless has_parent
                append str, indent, "var #{name} = FWI.util.exports().#{fqn_ns} || {};" unless is_root
            else
                append str, indent, "#{fqn_ns} = FWI.util.exports().#{fqn_ns} || {};" unless is_root
            end
            
            unless is_root
                append(str, indent, "FWI.util.exports().#{fqn_ns} = #{fqn_ns};")
            end

            ns[:members].each do |el_name, element|
                fqn = fqn_ns + "." + el_name
                fqn = el_name if is_root
                type_decl = is_root ? "var #{fqn}" : "#{fqn}"

                if element[:type] == :namespace
                    gen_for_ns(fqn_ns, el_name, element, str, indent);
                elsif element[:type] == :block
                    append str, indent, type_decl + " = FWI.block(\"#{fqn}\", #{element[:size]});"
                    element[:members].each do |mem|
                        gen_prototype(fqn, mem, str, indent)
                    end
                elsif element[:type] == :enum
                    maps = element[:members].map do |e|
                        "#{e[:name]}: #{e[:val]},"
                    end
                    maps.last.sub!(",","")
                    append str, indent, type_decl + " = {"
                    maps.each do |m|
                        append str, indent+1, m
                    end
                    append str, indent, "};"
                end
                
                if is_root && element[:type] != :namespace
                    append(str, indent, "FWI.util.exports().#{fqn} = #{fqn};")
                end
            end
        end

        def _get_for_file bitmap, file
            map = { :members => {}, :type => :namespace }
            bitmap[:members].each do |name, member|
                if member[:type] == :namespace
                    ret = _get_for_file member, file
                    map[:members][name] = ret unless ret[:members].empty?
                else
                    map[:members][name] = member if member[:file] == file
                end
            end
            map
        end

        def gen bitmap
            map = {}
            bitmap[:files].each do |name, file|
                filename = name.sub ".fwi", ".js"
                contents = "(function() {\n"

                gen_for_ns("<root>", "<root>", _get_for_file(bitmap, name), contents, 1)

                contents += "})();"
                map[filename] = contents
            end
            map
        end
    end
end
end