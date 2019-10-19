// CLightLcConfig.cpp : implementation file
//

#include "stdafx.h"
#include "MeshClient.h"
#include "LightLcConfig.h"
#include "afxdialogex.h"
#include "wiced_mesh_client.h"

extern "C" CRITICAL_SECTION cs;
extern DWORD GetHexValue(char* szbuf, LPBYTE buf, DWORD buf_size);

CLightLcConfig* pDlg = NULL;

typedef struct
{
    WCHAR* PropName;
    USHORT PropId;
    int len;
} LightLcProp;

LightLcProp lightLcProp[] =
{
    { L"Time Occupancy Delay (0x3a)", 0x3a, 3 },
    { L"Time Fade On (0x37)", 0x37, 3 },
    { L"Time Run On (0x3c)", 0x3c, 3 },
    { L"Time Fade (0x36)", 0x36, 3 },
    { L"Time Prolong (0x3b)", 0x3b, 3 },
    { L"Time Fade Standby Auto (0x38)", 0x38, 3 },
    { L"Time Fade Standby Manual (0x39)", 0x39, 3 },
    { L"Lightness On (0x2e)", 0x2e, 2 },
    { L"Lightness Prolong (0x2f)", 0x2f, 2 },
    { L"Lightness Standby (0x30)", 0x39, 2 },
    { L"Ambient LuxLevel On (0x2b)", 0x2b, 2 },
    { L"Ambient LuxLevel Prolong (0x2c)", 0x2c, 2 },
    { L"Ambient LuxLevel Standby (0x2d)", 0x2d, 2 },
    { L"Regulator Kiu (0x33)", 0x33, 4 },
    { L"Regulator Kid (0x32)", 0x32, 4 },
    { L"Regulator Kpu (0x35)", 0x35, 4 },
    { L"Regulator Kpd (0x34)", 0x34, 4 },
    { L"Regulator Accuracy (0x31)", 0x31, 1 },
};


// CLightLcConfig dialog

IMPLEMENT_DYNAMIC(CLightLcConfig, CDialogEx)

CLightLcConfig::CLightLcConfig(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_LC_CONFIG, pParent)
{
    pDlg = this;
}

CLightLcConfig::~CLightLcConfig()
{
    pDlg = NULL;
}

BOOL CLightLcConfig::OnInitDialog()
{
    CDialogEx::OnInitDialog();

    CComboBox* pLightLcProp = (CComboBox*)GetDlgItem(IDC_LIGHT_LC_PROPERTY);
    pLightLcProp->ResetContent();
    for (int i = 0; i < sizeof(lightLcProp) / sizeof(lightLcProp[0]); i++)
        pLightLcProp->AddString(lightLcProp[i].PropName);
    pLightLcProp->SetCurSel(0);
    return TRUE;  // return TRUE unless you set the focus to a control
                  // EXCEPTION: OCX Property Pages should return FALSE
}

void CLightLcConfig::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}


BEGIN_MESSAGE_MAP(CLightLcConfig, CDialogEx)
    ON_BN_CLICKED(IDC_LIGHT_LC_PROPERTY_GET, &CLightLcConfig::OnBnClickedLightLcPropertyGet)
    ON_BN_CLICKED(IDC_LIGHT_LC_PROPERTY_SET, &CLightLcConfig::OnBnClickedLightLcPropertySet)
    ON_BN_CLICKED(IDC_LIGHT_LC_MODE_GET, &CLightLcConfig::OnBnClickedLightLcModeGet)
    ON_BN_CLICKED(IDC_LIGHT_LC_OCCUPANCY_MODE_GET, &CLightLcConfig::OnBnClickedLightLcOccupancyModeGet)
    ON_BN_CLICKED(IDC_LIGHT_LC_ON_OFF_GET, &CLightLcConfig::OnBnClickedLightLcOnOffGet)
    ON_BN_CLICKED(IDC_LIGHT_LC_MODE_SET_ON, &CLightLcConfig::OnBnClickedLightLcModeSetOn)
    ON_BN_CLICKED(IDC_LIGHT_LC_MODE_SET_OFF, &CLightLcConfig::OnBnClickedLightLcModeSetOff)
    ON_BN_CLICKED(IDC_LIGHT_LC_OCCUPANCY_MODE_SET_ON, &CLightLcConfig::OnBnClickedLightLcOccupancyModeSetOn)
    ON_BN_CLICKED(IDC_LIGHT_LC_OCCUPANCY_MODE_SET_OFF, &CLightLcConfig::OnBnClickedLightLcOccupancyModeSetOff)
    ON_BN_CLICKED(IDC_LIGHT_LC_SET_ON, &CLightLcConfig::OnBnClickedLightLcSetOn)
    ON_BN_CLICKED(IDC_LIGHT_LC_SET_OFF, &CLightLcConfig::OnBnClickedLightLcSetOff)
END_MESSAGE_MAP()


// CLightLcConfig message handlers
void property_status_callback(const char* device_name, int property_id, int value)
{
    if (pDlg != NULL)
        pDlg->PropertyStatus(property_id, value);
}

void CLightLcConfig::PropertyStatus(int property_id, int value)
{
    CComboBox* pLightLcProp = (CComboBox*)GetDlgItem(IDC_LIGHT_LC_PROPERTY);
    for (int i = 0; i < sizeof(lightLcProp) / sizeof(lightLcProp[0]); i++)
    {
        if (lightLcProp[i].PropId == property_id)
        {
            pLightLcProp->SetCurSel(i);
            SetDlgItemInt(IDC_LIGHT_LC_PROPERTY_VALUE, value, 0);
        }
    }
}

void CLightLcConfig::OnBnClickedLightLcPropertyGet()
{
    CComboBox* pLightLcProp = (CComboBox*)GetDlgItem(IDC_LIGHT_LC_PROPERTY);
    int sel = pLightLcProp->GetCurSel();
    if (sel < 0)
        return;
    int property_id = lightLcProp[sel].PropId;
    EnterCriticalSection(&cs);
    mesh_client_light_lc_property_get(component_name, property_id, &property_status_callback);
    LeaveCriticalSection(&cs);
}


void CLightLcConfig::OnBnClickedLightLcPropertySet()
{
    CComboBox* pLightLcProp = (CComboBox*)GetDlgItem(IDC_LIGHT_LC_PROPERTY);
    int sel = pLightLcProp->GetCurSel();
    if (sel < 0)
        return;
    int property_id = lightLcProp[sel].PropId;
    int value = GetDlgItemInt(IDC_LIGHT_LC_PROPERTY_VALUE, 0, 0);
    EnterCriticalSection(&cs);
    mesh_client_light_lc_property_set(component_name, property_id, value, &property_status_callback);
    LeaveCriticalSection(&cs);
}

void lc_mode_status_callback(const char* device_name, int mode)
{
}

void CLightLcConfig::OnBnClickedLightLcModeGet()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_mode_get(component_name, &lc_mode_status_callback);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcModeSetOn()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_mode_set(component_name, 1, &lc_mode_status_callback);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcModeSetOff()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_mode_set(component_name, 0, &lc_mode_status_callback);
    LeaveCriticalSection(&cs);
}

void lc_occupancy_mode_status_callback(const char* device_name, int mode)
{
}

void CLightLcConfig::OnBnClickedLightLcOccupancyModeGet()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_occupancy_mode_get(component_name, &lc_occupancy_mode_status_callback);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcOccupancyModeSetOn()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_occupancy_mode_set(component_name, 1, &lc_occupancy_mode_status_callback);
    LeaveCriticalSection(&cs);
}


void CLightLcConfig::OnBnClickedLightLcOccupancyModeSetOff()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_occupancy_mode_set(component_name, 0, &lc_occupancy_mode_status_callback);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcOnOffGet()
{
    EnterCriticalSection(&cs);
    mesh_client_on_off_get(component_name);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcSetOn()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_on_off_set(component_name, 1, WICED_TRUE, DEFAULT_TRANSITION_TIME, 0);
    LeaveCriticalSection(&cs);
}

void CLightLcConfig::OnBnClickedLightLcSetOff()
{
    EnterCriticalSection(&cs);
    mesh_client_light_lc_on_off_set(component_name, 0, WICED_TRUE, DEFAULT_TRANSITION_TIME, 0);
    LeaveCriticalSection(&cs);
}
