/// This module provide all base type in LSP specification
/// and some extra utils (dynamic type).
///
pub const base_type = @import("base_type.zig");

const message = @import("message.zig");

pub const ResponseMessage = message.ResponseMessage;
pub const RequestMessage = message.RequestMessage;
pub const ParamTypes = message.ParamTypes;
pub const ResultTypes = message.ResultTypes;
pub const RequestParams = message.RequestParams;
pub const Result = message.Result;
