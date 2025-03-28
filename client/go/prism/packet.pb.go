// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.36.5
// 	protoc        v5.29.3
// source: packet.proto

package prism

import (
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	reflect "reflect"
	sync "sync"
	unsafe "unsafe"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

type DataPacket struct {
	state protoimpl.MessageState `protogen:"open.v1"`
	Type  int32                  `protobuf:"varint,1,opt,name=type,proto3" json:"type,omitempty"`
	// Types that are valid to be assigned to Payload:
	//
	//	*DataPacket_Login
	//	*DataPacket_AuthResponse
	//	*DataPacket_Update
	Payload       isDataPacket_Payload `protobuf_oneof:"payload"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *DataPacket) Reset() {
	*x = DataPacket{}
	mi := &file_packet_proto_msgTypes[0]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *DataPacket) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*DataPacket) ProtoMessage() {}

func (x *DataPacket) ProtoReflect() protoreflect.Message {
	mi := &file_packet_proto_msgTypes[0]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use DataPacket.ProtoReflect.Descriptor instead.
func (*DataPacket) Descriptor() ([]byte, []int) {
	return file_packet_proto_rawDescGZIP(), []int{0}
}

func (x *DataPacket) GetType() int32 {
	if x != nil {
		return x.Type
	}
	return 0
}

func (x *DataPacket) GetPayload() isDataPacket_Payload {
	if x != nil {
		return x.Payload
	}
	return nil
}

func (x *DataPacket) GetLogin() *Login {
	if x != nil {
		if x, ok := x.Payload.(*DataPacket_Login); ok {
			return x.Login
		}
	}
	return nil
}

func (x *DataPacket) GetAuthResponse() *AuthResponse {
	if x != nil {
		if x, ok := x.Payload.(*DataPacket_AuthResponse); ok {
			return x.AuthResponse
		}
	}
	return nil
}

func (x *DataPacket) GetUpdate() *Update {
	if x != nil {
		if x, ok := x.Payload.(*DataPacket_Update); ok {
			return x.Update
		}
	}
	return nil
}

type isDataPacket_Payload interface {
	isDataPacket_Payload()
}

type DataPacket_Login struct {
	Login *Login `protobuf:"bytes,2,opt,name=login,proto3,oneof"`
}

type DataPacket_AuthResponse struct {
	AuthResponse *AuthResponse `protobuf:"bytes,3,opt,name=auth_response,json=authResponse,proto3,oneof"`
}

type DataPacket_Update struct {
	Update *Update `protobuf:"bytes,4,opt,name=update,proto3,oneof"`
}

func (*DataPacket_Login) isDataPacket_Payload() {}

func (*DataPacket_AuthResponse) isDataPacket_Payload() {}

func (*DataPacket_Update) isDataPacket_Payload() {}

type Login struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Service       string                 `protobuf:"bytes,1,opt,name=service,proto3" json:"service,omitempty"`
	Token         string                 `protobuf:"bytes,2,opt,name=token,proto3" json:"token,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Login) Reset() {
	*x = Login{}
	mi := &file_packet_proto_msgTypes[1]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Login) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Login) ProtoMessage() {}

func (x *Login) ProtoReflect() protoreflect.Message {
	mi := &file_packet_proto_msgTypes[1]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Login.ProtoReflect.Descriptor instead.
func (*Login) Descriptor() ([]byte, []int) {
	return file_packet_proto_rawDescGZIP(), []int{1}
}

func (x *Login) GetService() string {
	if x != nil {
		return x.Service
	}
	return ""
}

func (x *Login) GetToken() string {
	if x != nil {
		return x.Token
	}
	return ""
}

type AuthResponse struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Status        int32                  `protobuf:"varint,1,opt,name=status,proto3" json:"status,omitempty"`
	Message       string                 `protobuf:"bytes,2,opt,name=message,proto3" json:"message,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *AuthResponse) Reset() {
	*x = AuthResponse{}
	mi := &file_packet_proto_msgTypes[2]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *AuthResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*AuthResponse) ProtoMessage() {}

func (x *AuthResponse) ProtoReflect() protoreflect.Message {
	mi := &file_packet_proto_msgTypes[2]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use AuthResponse.ProtoReflect.Descriptor instead.
func (*AuthResponse) Descriptor() ([]byte, []int) {
	return file_packet_proto_rawDescGZIP(), []int{2}
}

func (x *AuthResponse) GetStatus() int32 {
	if x != nil {
		return x.Status
	}
	return 0
}

func (x *AuthResponse) GetMessage() string {
	if x != nil {
		return x.Message
	}
	return ""
}

type Update struct {
	state         protoimpl.MessageState `protogen:"open.v1"`
	Name          string                 `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Value         string                 `protobuf:"bytes,2,opt,name=value,proto3" json:"value,omitempty"`
	Type          string                 `protobuf:"bytes,3,opt,name=type,proto3" json:"type,omitempty"`
	PersistCache  bool                   `protobuf:"varint,4,opt,name=persist_cache,json=persistCache,proto3" json:"persist_cache,omitempty"`
	unknownFields protoimpl.UnknownFields
	sizeCache     protoimpl.SizeCache
}

func (x *Update) Reset() {
	*x = Update{}
	mi := &file_packet_proto_msgTypes[3]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *Update) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Update) ProtoMessage() {}

func (x *Update) ProtoReflect() protoreflect.Message {
	mi := &file_packet_proto_msgTypes[3]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Update.ProtoReflect.Descriptor instead.
func (*Update) Descriptor() ([]byte, []int) {
	return file_packet_proto_rawDescGZIP(), []int{3}
}

func (x *Update) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *Update) GetValue() string {
	if x != nil {
		return x.Value
	}
	return ""
}

func (x *Update) GetType() string {
	if x != nil {
		return x.Type
	}
	return ""
}

func (x *Update) GetPersistCache() bool {
	if x != nil {
		return x.PersistCache
	}
	return false
}

var File_packet_proto protoreflect.FileDescriptor

var file_packet_proto_rawDesc = string([]byte{
	0x0a, 0x0c, 0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x0a,
	0x6e, 0x65, 0x74, 0x2e, 0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x22, 0xc5, 0x01, 0x0a, 0x0a, 0x44,
	0x61, 0x74, 0x61, 0x50, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x12, 0x12, 0x0a, 0x04, 0x74, 0x79, 0x70,
	0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x05, 0x52, 0x04, 0x74, 0x79, 0x70, 0x65, 0x12, 0x29, 0x0a,
	0x05, 0x6c, 0x6f, 0x67, 0x69, 0x6e, 0x18, 0x02, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x11, 0x2e, 0x6e,
	0x65, 0x74, 0x2e, 0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x2e, 0x4c, 0x6f, 0x67, 0x69, 0x6e, 0x48,
	0x00, 0x52, 0x05, 0x6c, 0x6f, 0x67, 0x69, 0x6e, 0x12, 0x3f, 0x0a, 0x0d, 0x61, 0x75, 0x74, 0x68,
	0x5f, 0x72, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x18, 0x03, 0x20, 0x01, 0x28, 0x0b, 0x32,
	0x18, 0x2e, 0x6e, 0x65, 0x74, 0x2e, 0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x2e, 0x41, 0x75, 0x74,
	0x68, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x48, 0x00, 0x52, 0x0c, 0x61, 0x75, 0x74,
	0x68, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x12, 0x2c, 0x0a, 0x06, 0x75, 0x70, 0x64,
	0x61, 0x74, 0x65, 0x18, 0x04, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x12, 0x2e, 0x6e, 0x65, 0x74, 0x2e,
	0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x2e, 0x55, 0x70, 0x64, 0x61, 0x74, 0x65, 0x48, 0x00, 0x52,
	0x06, 0x75, 0x70, 0x64, 0x61, 0x74, 0x65, 0x42, 0x09, 0x0a, 0x07, 0x70, 0x61, 0x79, 0x6c, 0x6f,
	0x61, 0x64, 0x22, 0x37, 0x0a, 0x05, 0x4c, 0x6f, 0x67, 0x69, 0x6e, 0x12, 0x18, 0x0a, 0x07, 0x73,
	0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x07, 0x73, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x12, 0x14, 0x0a, 0x05, 0x74, 0x6f, 0x6b, 0x65, 0x6e, 0x18, 0x02,
	0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x74, 0x6f, 0x6b, 0x65, 0x6e, 0x22, 0x40, 0x0a, 0x0c, 0x41,
	0x75, 0x74, 0x68, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x12, 0x16, 0x0a, 0x06, 0x73,
	0x74, 0x61, 0x74, 0x75, 0x73, 0x18, 0x01, 0x20, 0x01, 0x28, 0x05, 0x52, 0x06, 0x73, 0x74, 0x61,
	0x74, 0x75, 0x73, 0x12, 0x18, 0x0a, 0x07, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x18, 0x02,
	0x20, 0x01, 0x28, 0x09, 0x52, 0x07, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x22, 0x6b, 0x0a,
	0x06, 0x55, 0x70, 0x64, 0x61, 0x74, 0x65, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18,
	0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x12, 0x14, 0x0a, 0x05, 0x76,
	0x61, 0x6c, 0x75, 0x65, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x76, 0x61, 0x6c, 0x75,
	0x65, 0x12, 0x12, 0x0a, 0x04, 0x74, 0x79, 0x70, 0x65, 0x18, 0x03, 0x20, 0x01, 0x28, 0x09, 0x52,
	0x04, 0x74, 0x79, 0x70, 0x65, 0x12, 0x23, 0x0a, 0x0d, 0x70, 0x65, 0x72, 0x73, 0x69, 0x73, 0x74,
	0x5f, 0x63, 0x61, 0x63, 0x68, 0x65, 0x18, 0x04, 0x20, 0x01, 0x28, 0x08, 0x52, 0x0c, 0x70, 0x65,
	0x72, 0x73, 0x69, 0x73, 0x74, 0x43, 0x61, 0x63, 0x68, 0x65, 0x42, 0x0e, 0x5a, 0x0c, 0x6e, 0x65,
	0x74, 0x2f, 0x70, 0x61, 0x63, 0x6b, 0x65, 0x74, 0x70, 0x62, 0x62, 0x06, 0x70, 0x72, 0x6f, 0x74,
	0x6f, 0x33,
})

var (
	file_packet_proto_rawDescOnce sync.Once
	file_packet_proto_rawDescData []byte
)

func file_packet_proto_rawDescGZIP() []byte {
	file_packet_proto_rawDescOnce.Do(func() {
		file_packet_proto_rawDescData = protoimpl.X.CompressGZIP(unsafe.Slice(unsafe.StringData(file_packet_proto_rawDesc), len(file_packet_proto_rawDesc)))
	})
	return file_packet_proto_rawDescData
}

var file_packet_proto_msgTypes = make([]protoimpl.MessageInfo, 4)
var file_packet_proto_goTypes = []any{
	(*DataPacket)(nil),   // 0: net.packet.DataPacket
	(*Login)(nil),        // 1: net.packet.Login
	(*AuthResponse)(nil), // 2: net.packet.AuthResponse
	(*Update)(nil),       // 3: net.packet.Update
}
var file_packet_proto_depIdxs = []int32{
	1, // 0: net.packet.DataPacket.login:type_name -> net.packet.Login
	2, // 1: net.packet.DataPacket.auth_response:type_name -> net.packet.AuthResponse
	3, // 2: net.packet.DataPacket.update:type_name -> net.packet.Update
	3, // [3:3] is the sub-list for method output_type
	3, // [3:3] is the sub-list for method input_type
	3, // [3:3] is the sub-list for extension type_name
	3, // [3:3] is the sub-list for extension extendee
	0, // [0:3] is the sub-list for field type_name
}

func init() { file_packet_proto_init() }
func file_packet_proto_init() {
	if File_packet_proto != nil {
		return
	}
	file_packet_proto_msgTypes[0].OneofWrappers = []any{
		(*DataPacket_Login)(nil),
		(*DataPacket_AuthResponse)(nil),
		(*DataPacket_Update)(nil),
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: unsafe.Slice(unsafe.StringData(file_packet_proto_rawDesc), len(file_packet_proto_rawDesc)),
			NumEnums:      0,
			NumMessages:   4,
			NumExtensions: 0,
			NumServices:   0,
		},
		GoTypes:           file_packet_proto_goTypes,
		DependencyIndexes: file_packet_proto_depIdxs,
		MessageInfos:      file_packet_proto_msgTypes,
	}.Build()
	File_packet_proto = out.File
	file_packet_proto_goTypes = nil
	file_packet_proto_depIdxs = nil
}
