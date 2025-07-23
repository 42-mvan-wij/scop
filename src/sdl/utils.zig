const std = @import("std");
pub fn Mask(comptime Enum: type) type {
    const TagType = @typeInfo(Enum).@"enum".tag_type;
    const fields = @typeInfo(Enum).@"enum".fields;

    var struct_fields: [fields.len]std.builtin.Type.StructField = undefined;
    for (fields, &struct_fields) |field, *struct_field| {
        struct_field.name = field.name;
        struct_field.type = bool;
        struct_field.default_value_ptr = &false;
        struct_field.alignment = @alignOf(bool);
        struct_field.is_comptime = false;
    }
    const struct_fields_const = struct_fields;
    return struct {
        pub const Flags = @Type(std.builtin.Type{.@"struct" = std.builtin.Type.Struct{
            .fields = &struct_fields_const,
            .decls = &.{},
            .layout = .auto,
            .is_tuple = false,
            .backing_integer = null,
        }});

        pub fn convert(flags: Flags) TagType {
            var value: TagType = 0;
            inline for (fields) |field| {
                value |= if (@field(flags, field.name)) field.value else 0;
            }
            return value;
        }
    };
}
