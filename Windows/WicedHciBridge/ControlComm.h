#ifndef CONTROL_COMM_H
#define CONTROL_COMM_H

//**************************************************************************************************
//*** Definitions for BTW Serial Bus
//**************************************************************************************************

//
// Serial Bus class, use this class to read/write from/to the serial bus device
//
class ComHelper
{
public:
    ComHelper();
    virtual ~ComHelper( );

	// oopen serialbus driver to access device
    BOOL OpenPort( int port, int baudRate );
    void ClosePort( );

	// read data from device
    DWORD Read( LPBYTE b, DWORD dwLen );
    DWORD ReadNewHciPacket( BYTE * pu8Buffer, int bufLen, int * pOffset );
    DWORD ReadWorker( );

	// write data to device
    DWORD Write( LPBYTE b, DWORD dwLen );

    void SetMutex(HANDLE uMutex);

    BOOL IsOpened( );

    HANDLE m_hWaitContinue;
    BOOL   m_bWaitContinue;
private:
    HWND m_hWnd;
	// overlap IO for Read and Write
    OVERLAPPED m_OverlapRead;
    OVERLAPPED m_OverlapWrite;
    HANDLE m_handle;
    HANDLE m_hThreadRead;
    HANDLE m_hShutdown;
    BOOL m_bClosing;
    BOOL m_CleanHciState;
};

#endif
