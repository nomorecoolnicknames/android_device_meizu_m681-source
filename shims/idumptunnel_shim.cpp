/* libdumptunnel_shim - provides android::IDumpTunnel::asInterface(sp<IBinder>const&)
 * which MTK's libgui exports but AOSP's does not; libgui_ext.so imports it.
 * Returns a null sp<IDumpTunnel> via an ABI-identical single-pointer struct with
 * a non-trivial dtor (returned indirectly/sret, matching sp<T>). No deps. */
namespace { struct ShimSp { void* p; ~ShimSp() {} }; }
extern "C" ShimSp
_ZN7android11IDumpTunnel11asInterfaceERKNS_2spINS_7IBinderEEE(const void* /*binder*/) {
    ShimSp r; r.p = 0; return r;
}
