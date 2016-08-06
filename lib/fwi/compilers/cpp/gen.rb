module FWI
module Generator
    class CPP
        TYPE_MAP = {
            :float64 => "double",
            :float32 => "float",
            :u64 => "uint64_t",
            :u32 => "uint32_t",
            :u16 => "uint16_t",
            :u8 => "uint8_t",
            :i64 => "int64_t",
            :i32 => "int32_t",
            :i16 => "int16_t",
            :i8 => "int8_t",
            :string => "char *",
            :bool => "bool"
        };

        def append buffer, indent, string
            string.split(/\n/).each { |y| buffer << ("\t" * indent) + y + "\n" }
        end

        def _write_fwd_child name, child, indent, buffer
            if child[:type] == :namespace
                _write_fwd name, child, indent, buffer
            elsif child[:type] == :block
                append(buffer, indent, "struct #{name};")
            elsif child[:type] == :enum
                type = child[:reltype]
                append(buffer, indent, "enum class #{name} {")
                indent += 1
                append(buffer, indent, child[:members].map { |n| "#{n[:name]} = #{n[:val]}" }.join(",\n"))
                indent -= 1
                append(buffer, indent, "};")
            end
        end

        def _write_fwd name, namespace, indent, buffer
            append(buffer, indent, "namespace #{name} {")
            indent += 1
            namespace[:members].each do |name, child|
                _write_fwd_child name, child, indent, buffer
            end
            indent -= 1
            append(buffer, indent, "}")
        end

        def write_fwd_declarations str, root, indent
            root[:members].each do |name, child|
                _write_fwd_child name, child, indent, str
            end
        end

        def _func_util mode, name, member, truncate=true, relative_types=true, fulltype=""
            type = member[:type]
            type_sym = relative_types ? :reltype : :element_name

            ctype = TYPE_MAP[type]
            ctype = member[type_sym] + (member[:element_type] == :block ? " *" : "") if (member[:type] == :reference)
            ctype = member[:attribute_map]["ctype"] unless member[:attribute_map]["ctype"].nil?

            param = member[:array].nil? ? "" : "int index#{mode == :setter ? ', ' : ''}"
            custom_getter = member[:attribute_map]["getter"]
            custom_setter = member[:attribute_map]["setter"]
            custom_length = member[:attribute_map]["length_func"]
            prefix = relative_types ? "" : (fulltype + "::")
            func_name = prefix
            func_sig = ""
            if mode == :setter
                func_name += custom_setter.nil? ? "set_#{name}" : custom_setter
                func_sig = "void #{func_name}(#{param}#{ctype} value)"
            elsif mode == :getter
                func_name += custom_getter.nil? ? "get_#{name}" : custom_getter
                func_sig = "#{ctype} #{func_name}(#{param})"
            elsif mode == :length
                func_name += custom_length.nil? ? "#{name}_length" : custom_length
                func_sig = "int #{func_name}(#{param})"
            end
            func_sig += truncate ? ";" : ' {'
            index = member[:index]
            index = "#{index} + (#{member[:typesize]} * index)" unless member[:array].nil?
            { :ctype => ctype, :prefix => prefix, :func_name => func_name, :func_sig => func_sig, :index => index }
        end

        def write_getter str, name, member, indent, truncate=true, relative_types=true, fulltype=""
            return "" if member[:attributes].include? "no-getter"
            util = _func_util :getter, name, member, truncate, relative_types, fulltype

            append(str, indent, util[:func_sig])
            unless truncate
                type = member[:type]
                ctype = util[:ctype]

                indent += 1
                if type == :reference
                    if member[:element_type] == :enum
                        append(str, indent, "return (#{ctype})(_store[#{util[:index]}]);")
                    else
                        if member[:array].nil?
                            append(str, indent, "return &_#{member[:name]};")
                        else
                            append(str, indent, "return &_#{member[:name]}[index];")
                        end
                    end
                elsif type == :string
                    append(str, indent, "return (_store + #{util[:index]});")
                elsif type == :bool
                    if member[:array].nil?
                        append(str, indent, "return FWI_IS_BIT_SET(_store[#{util[:index]}], #{member[:bit_index]});")
                    else
                        append(str, indent, "return FWI_IS_BIT_SET(_store[#{member[:index]} + index / 8], index % 8);")
                    end
                else
                    append(str, indent, "return FWI_MEM_VAL(#{util[:ctype]}, _store, #{util[:index]});")
                end
                indent -= 1
                append(str, indent, "}")
            end
            str
        end

        def write_setter str, name, member, indent, truncate=true, relative_types=true, fulltype=""
            return "" if member[:attributes].include? "no-setter"
            util = _func_util :setter, name, member, truncate, relative_types, fulltype

            append(str, indent, util[:func_sig])
            unless truncate
                type = member[:type]
                ctype = util[:ctype]

                indent += 1
                if type == :reference
                    append(str, indent, "_store[#{util[:index]}] = (char)value;")
                elsif type == :bool
                    if member[:array].nil?
                        append(str, indent, "FWI_SET_BIT_TO(_store[#{util[:index]}], #{member[:bit_index]}, value ? 1 : 0);")
                    else
                        append(str, indent, "FWI_SET_BIT_TO(_store[#{member[:index]} + index / 8], index % 8, value ? 1 : 0);")
                    end
                else
                    append(str, indent, "FWI_MEM_VAL(#{ctype}, _store, #{util[:index]}) = value;")
                end
                indent -= 1
                append(str, indent, "}")
            end
            str
        end

        def write_length str, name, member, indent, truncate=true, relative_types=true, fulltype=""
            return "" if member[:attributes].include? "no-len"
            util = _func_util :length, name, member, truncate, relative_types, fulltype

            append(str, indent, util[:func_sig])
            unless truncate
                indent += 1
                append(str, indent, "return #{member[:size]};")
                indent -= 1
                append(str, indent, "}")
            end
            str
        end

        def write_ptr_update buffer, b_refs, indent, truncate=true, prefix=""
            unless b_refs.empty?
                virt = prefix.empty? ? "virtual " : ""
                if truncate
                    append(buffer, indent, "#{virt}void #{prefix}_update_ptr();")
                else
                    append(buffer, indent, "#{virt}void #{prefix}_update_ptr() {")
                    indent += 1
                    i_def = false
                    b_refs.each do |ref|
                        if ref[:array].nil?
                            append(buffer, indent, "_#{ref[:name]}.map_to(_store + #{ref[:index]});")
                        else
                            unless i_def
                                i_def = true
                                append(buffer, indent, "int i;")
                            end
                            append(buffer, indent, "for (i = 0; i < #{ref[:array]}; i++) {")
                            indent += 1
                            append(buffer, indent, "_#{ref[:name]}[i].map_to(_store + #{ref[:index]} + (#{ref[:typesize]} * i));")
                            indent -= 1
                            append(buffer, indent, "}")
                        end
                    end
                    indent -= 1
                    append(buffer, indent, "}")
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

        def gen_hpp_for buffer, indent, filtered, hpp_only
            namespace, object = filtered[:members].partition { |n,x| x[:type] == :namespace }

            object.select { |n,x| x[:type] == :block }.each do |name, block|
                append(buffer, indent, "struct #{name} : public FWI::Block {")
                indent += 1
                append(buffer, indent, "static const int SIZE = #{block[:size]};")
                b_refs, mems = block[:members].partition { |x| x[:type] == :reference && x[:element_type] == :block }
                buffer << "\n"

                trunc = !hpp_only

                b_refs.each do |block_ref|
                    write_getter buffer, block_ref[:name], block_ref, indent, trunc, true
                    buffer << "\n"
                end

                mems.each do |member_ref|
                    write_getter buffer, member_ref[:name], member_ref, indent, trunc, true
                    if member_ref[:type] == :string
                        write_length buffer, member_ref[:name], member_ref, indent, trunc, true
                    else
                        write_setter buffer, member_ref[:name], member_ref, indent, trunc, true
                    end
                    buffer << "\n"
                end

                b_refs.each do |block_ref|
                    if block_ref[:array].nil?
                        append(buffer, indent, "#{block_ref[:reltype]} _#{block_ref[:name]};")
                    else
                        append(buffer, indent, "#{block_ref[:reltype]} _#{block_ref[:name]}[#{block_ref[:array]}];")
                    end
                end

                buffer << "\n"

                write_ptr_update buffer, b_refs, indent, trunc

                indent -= 1
                append(buffer, indent, "}; // struct: #{name}")
            end

            namespace.each do |name, ns|
                append(buffer, indent, "namespace #{name} {")
                gen_hpp_for buffer, indent + 1, ns, hpp_only
                append(buffer, indent, "} // namespace: #{name}")
            end
        end

        def gen_cpp_for buffer, indent, blocks
            blocks.each do |obj|
                name = obj[:name]
                block = obj[:block]

                b_refs, mems = block[:members].partition { |x| x[:type] == :reference && x[:element_type] == :block }

                b_refs.each do |block_ref|
                    write_getter buffer, block_ref[:name], block_ref, indent, false, false, block[:fulltype]
                    buffer << "\n"
                end

                mems.each do |member_ref|
                    write_getter buffer, member_ref[:name], member_ref, indent, false, false, block[:fulltype]
                    if member_ref[:type] == :string
                        write_length buffer, member_ref[:name], member_ref, indent, false, false, block[:fulltype]
                    else
                        write_setter buffer, member_ref[:name], member_ref, indent, false, false, block[:fulltype]
                    end
                    buffer << "\n"
                end

                buffer << "\n"

                write_ptr_update(buffer, b_refs, indent, false, (block[:fulltype] + "::"))
            end
        end

        def gen_hpp bitmap, hpp_ext, hpp_only
            map = {}
            bitmap[:files].each do |name, file|
                filename = name.sub ".fwi", hpp_ext
                contents = "#pragma once\n\n#include \"fwi.hpp\"\n"
                file[:imports].each do |import|
                    append(contents, 0, "#include \"#{import.sub '.fwi', hpp_ext}\"")
                end
                contents << "\n" unless file[:imports].empty?

                filtered_bitmap = _get_for_file(bitmap, name)

                write_fwd_declarations contents, filtered_bitmap, 0
                contents << "\n"
                gen_hpp_for contents, 0, filtered_bitmap, hpp_only

                map[filename] = contents
            end
            map
        end

        def gen_cpp bitmap, cpp_ext, hpp_ext
            map = {}
            bitmap[:files].each do |name, file|
                filename = name.sub ".fwi", cpp_ext
                contents = "#include \"#{name.sub '.fwi', hpp_ext}\"\n\n"

                blocks = file[:blocks].map do |b|
                    ref = bitmap
                    name = ""
                    b.split("::").each do |c|
                        ref = ref[:members][c]
                        name = c
                    end
                    { :name => name, :block => ref }
                end

                gen_cpp_for contents, 0, blocks

                map[filename] = contents
            end
            map
        end
    end
end
end