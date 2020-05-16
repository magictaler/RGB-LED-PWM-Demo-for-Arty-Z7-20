/*
 FreeRTOS based RGB PWM LED Demo for Arty Z7-20 board
 ====================================================

 This demo is a 'Hello World' application type running on
 Zynq FPGA chip from Xilinx and a starting point for 
 doing Block design, IP Core creation, FreeRTOS application
 development, integration of PL and PS sides and packaging
 the whole project into a compact and elegant solution which
 sets a reference point for future projects.

 This project has a custom designed IP Core capable of
 driving 6 independent PWM channels which outputs are 
 directly connected to the two RGB LEDs of the Arty board. 
 
 Copyright (c) 2020 Dmitry Pakhomenko.
 dmitryp@magictale.com
 http://magictale.com
 
 This code is in the public domain.
*/

/* FreeRTOS includes. */
#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
/* Xilinx includes. */
#include "xil_printf.h"
#include "xparameters.h"
#include "xil_io.h"

#define BTIMER_ID 1
#define GTIMER_ID 2
#define RTIMER_ID 3
#define DELAY_1_SECOND 1000UL
#define DELAY_30_MSECONDS 30UL
#define DELAY_40_MSECONDS 40UL
#define DELAY_50_MSECONDS 50UL

#define RGB_LED_PWM_BASE XPAR_LED_PWM_0_S00_AXI_BASEADDR
#define RGB_LED_PWM_MODULE_OFFSET 0
#define RGB_LED0_PWM_BLUE_WIDTH_OFFSET 1
#define RGB_LED0_PWM_GREEN_WIDTH_OFFSET 2
#define RGB_LED0_PWM_RED_WIDTH_OFFSET 3
#define RGB_LED1_PWM_BLUE_WIDTH_OFFSET 4
#define RGB_LED1_PWM_GREEN_WIDTH_OFFSET 5
#define RGB_LED1_PWM_RED_WIDTH_OFFSET 6

#define RGB_LED_OFFSET_MULTIPLIER 4
#define RGB_LED_MAX_DUTY_CYCLE 0x30
#define RGB_LED_PWM_MODULE 0x80
#define ITEGRATIONS_IN_RGB_MODE 10

typedef enum
{
    RED_MODE = 0,
    GREEN_MODE,
    BLUE_MODE,
    RGB_MODE,
    END_MODE
} Blinking_Mode_Enum;

typedef struct
{
    uint8_t id;
    uint8_t duty_cycle;
    uint8_t intensity_ascending;
    uint8_t register_offset;
    TimerHandle_t xTimer;
} LED_Descriptor_Struct;

typedef struct
{
    LED_Descriptor_Struct leds[3];
    Blinking_Mode_Enum blinking_mode;
    uint8_t iterations_in_rgb_mode;
} RGB_LED_Descriptor_Struct;

static void prvLedCtrlTask(void *pvParameters);
static void vBlue0TimerCallback(TimerHandle_t pxTimer);
static void vGreen0TimerCallback(TimerHandle_t pxTimer);
static void vRed0TimerCallback(TimerHandle_t pxTimer);
static void vBlue1TimerCallback(TimerHandle_t pxTimer);
static void vGreen1TimerCallback(TimerHandle_t pxTimer);
static void vRed1TimerCallback(TimerHandle_t pxTimer);
static void vUpdateDutyCycle(RGB_LED_Descriptor_Struct * p_rgb_led_descriptor,
    LED_Descriptor_Struct * p_led_descriptor, uint8_t progress_mode);
static void progressBlinkingMode(RGB_LED_Descriptor_Struct * p_rgb_led_descriptor);

static TaskHandle_t xLedControlTask;
static RGB_LED_Descriptor_Struct rgb_led0 =
    {.leds =
        {
            {.id = RED_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED0_PWM_RED_WIDTH_OFFSET, .xTimer = NULL},
            {.id = GREEN_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED0_PWM_GREEN_WIDTH_OFFSET, .xTimer = NULL},
            {.id = BLUE_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED0_PWM_BLUE_WIDTH_OFFSET, .xTimer = NULL}
        },
      .blinking_mode = RED_MODE,
      .iterations_in_rgb_mode = ITEGRATIONS_IN_RGB_MODE
    };

static RGB_LED_Descriptor_Struct rgb_led1 =
    {.leds =
        {
            {.id = RED_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED1_PWM_RED_WIDTH_OFFSET, .xTimer = NULL},
            {.id = GREEN_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED1_PWM_GREEN_WIDTH_OFFSET, .xTimer = NULL},
            {.id = BLUE_MODE, .duty_cycle = 0, .intensity_ascending = TRUE, .register_offset = RGB_LED1_PWM_BLUE_WIDTH_OFFSET, .xTimer = NULL}
        },
      .blinking_mode = RED_MODE,
      .iterations_in_rgb_mode = ITEGRATIONS_IN_RGB_MODE / 2
    };


int main(void)
{
    const TickType_t x30mseconds = pdMS_TO_TICKS(DELAY_30_MSECONDS);
    const TickType_t x40mseconds = pdMS_TO_TICKS(DELAY_40_MSECONDS);
    const TickType_t x50mseconds = pdMS_TO_TICKS(DELAY_50_MSECONDS);

    xil_printf("\r\n\r\nFreeRTOS version of RGB LED PWM Demo for Arty Z7-20 board\r\n");

    xTaskCreate(prvLedCtrlTask, /* The function that implements the task. */
                (const char*) "Led", /* Text name for the task, provided to assist debugging only. */
                configMINIMAL_STACK_SIZE, /* The stack allocated to the task. */
                NULL, /* The task parameter is not used, so set to NULL. */
                tskIDLE_PRIORITY, /* The task runs at the idle priority. */
                &xLedControlTask );

    //=== LED 0 ===
    rgb_led0.leds[BLUE_MODE].xTimer = xTimerCreate((const char *)"Blue0Timer",
                x30mseconds,
                pdFALSE,
                (void*)BTIMER_ID,
                vBlue0TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led0.leds[BLUE_MODE].xTimer);

    rgb_led0.leds[GREEN_MODE].xTimer = xTimerCreate((const char *)"Green0Timer",
                x40mseconds,
                pdFALSE,
                (void*)GTIMER_ID,
                vGreen0TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led0.leds[GREEN_MODE].xTimer);

    rgb_led0.leds[RED_MODE].xTimer = xTimerCreate((const char *)"Red0Timer",
                x50mseconds,
                pdFALSE,
                (void*)RTIMER_ID,
                vRed0TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led0.leds[RED_MODE].xTimer);

    //=== LED 1 ===
    rgb_led1.leds[BLUE_MODE].xTimer = xTimerCreate((const char *)"Blue1Timer",
                x30mseconds / 2,
                pdFALSE,
                (void*)BTIMER_ID,
                vBlue1TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led1.leds[BLUE_MODE].xTimer);

    rgb_led1.leds[GREEN_MODE].xTimer = xTimerCreate((const char *)"Green1Timer",
                x40mseconds / 2,
                pdFALSE,
                (void*)GTIMER_ID,
                vGreen1TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led1.leds[GREEN_MODE].xTimer);

    rgb_led1.leds[RED_MODE].xTimer = xTimerCreate((const char *)"Red1Timer",
                x50mseconds / 2,
                pdFALSE,
                (void*)RTIMER_ID,
                vRed1TimerCallback);
    /* Check the timer was created. */
    configASSERT(rgb_led0.leds[RED_MODE].xTimer);


    Xil_Out32(RGB_LED_PWM_BASE + RGB_LED_PWM_MODULE_OFFSET, RGB_LED_PWM_MODULE);

    /* start the timers with a block time of 0 ticks. This means as soon
       as the schedule starts the timers will start running and will expire after
       predefined number of milliseconds */
    xTimerStart(rgb_led0.leds[RED_MODE].xTimer, 0);
    xTimerStart(rgb_led0.leds[GREEN_MODE].xTimer, 0);
    xTimerStart(rgb_led0.leds[BLUE_MODE].xTimer, 0);

    xTimerStart(rgb_led1.leds[RED_MODE].xTimer, 0);
    xTimerStart(rgb_led1.leds[GREEN_MODE].xTimer, 0);
    xTimerStart(rgb_led1.leds[BLUE_MODE].xTimer, 0);

    /* Start the tasks and timer running. */
    vTaskStartScheduler();

    /* If all is well, the scheduler will now be running, and the following line
    will never be reached.  If the following line does execute, then there was
    insufficient FreeRTOS heap memory available for the idle and/or timer tasks
    to be created.  See the memory management section on the FreeRTOS web site
    for more details. */
    for(;;);
}

void progressBlinkingMode(RGB_LED_Descriptor_Struct * p_rgb_led_descriptor)
{
    if (p_rgb_led_descriptor->blinking_mode == RGB_MODE)
    {
        // In RGB mode we don't immediately progress to the next state but rather
        // loop for several cycles defined in iterations_in_rgb_mode
        if (p_rgb_led_descriptor->iterations_in_rgb_mode == 0)
        {
            p_rgb_led_descriptor->blinking_mode++;
        }
        else
        {
            p_rgb_led_descriptor->iterations_in_rgb_mode--;
        }
    }
    else
    {
        p_rgb_led_descriptor->blinking_mode++;
    }

    if (p_rgb_led_descriptor->blinking_mode >= END_MODE)
    {
        p_rgb_led_descriptor->blinking_mode = RED_MODE;

        Xil_Out32(RGB_LED_PWM_BASE + p_rgb_led_descriptor->leds[RED_MODE].register_offset * RGB_LED_OFFSET_MULTIPLIER, 0);
        Xil_Out32(RGB_LED_PWM_BASE + p_rgb_led_descriptor->leds[GREEN_MODE].register_offset * RGB_LED_OFFSET_MULTIPLIER, 0);
        Xil_Out32(RGB_LED_PWM_BASE + p_rgb_led_descriptor->leds[BLUE_MODE].register_offset * RGB_LED_OFFSET_MULTIPLIER, 0);

        p_rgb_led_descriptor->leds[RED_MODE].duty_cycle = 0;
        p_rgb_led_descriptor->leds[GREEN_MODE].duty_cycle = 0;
        p_rgb_led_descriptor->leds[BLUE_MODE].duty_cycle = 0;

        p_rgb_led_descriptor->leds[RED_MODE].intensity_ascending = TRUE;
        p_rgb_led_descriptor->leds[GREEN_MODE].intensity_ascending = TRUE;
        p_rgb_led_descriptor->leds[BLUE_MODE].intensity_ascending = TRUE;
        p_rgb_led_descriptor->iterations_in_rgb_mode = ITEGRATIONS_IN_RGB_MODE;
    }
}

static void prvLedCtrlTask(void *pvParameters)
{
    const TickType_t x1second = pdMS_TO_TICKS( DELAY_1_SECOND );
    for(;;)
    {
        /* Delay for 1 second. */
        vTaskDelay(x1second);
        // TODO: instead of just waiting for timers do something useful in main thread
    }
}

static void vUpdateDutyCycle(RGB_LED_Descriptor_Struct * p_rgb_led_descriptor,
    LED_Descriptor_Struct * p_led_descriptor, uint8_t progress_mode)
{
    UBaseType_t uxSavedInterruptStatus;
    uxSavedInterruptStatus = taskENTER_CRITICAL_FROM_ISR();

    if (
        (p_rgb_led_descriptor->blinking_mode == RGB_MODE) ||
        (p_rgb_led_descriptor->blinking_mode == RED_MODE && p_led_descriptor->id == RED_MODE) ||
        (p_rgb_led_descriptor->blinking_mode == BLUE_MODE && p_led_descriptor->id == BLUE_MODE) ||
        (p_rgb_led_descriptor->blinking_mode == GREEN_MODE && p_led_descriptor->id == GREEN_MODE)
        )
    {
        Xil_Out32(RGB_LED_PWM_BASE + p_led_descriptor->register_offset * RGB_LED_OFFSET_MULTIPLIER, p_led_descriptor->duty_cycle);


        if ( p_led_descriptor->intensity_ascending == TRUE )
        {
            p_led_descriptor->duty_cycle++;
            if (p_led_descriptor->duty_cycle >= RGB_LED_MAX_DUTY_CYCLE)
            {
                p_led_descriptor->intensity_ascending = FALSE;
            }
        }
        else
        {
            p_led_descriptor->duty_cycle--;
            if (p_led_descriptor->duty_cycle == 0)
            {
                p_led_descriptor->intensity_ascending = TRUE;
                if ((progress_mode == TRUE && p_rgb_led_descriptor->blinking_mode == RGB_MODE) ||
                     p_rgb_led_descriptor->blinking_mode == RED_MODE ||
                     p_rgb_led_descriptor->blinking_mode == BLUE_MODE ||
                     p_rgb_led_descriptor->blinking_mode == GREEN_MODE
                   )
                {
                    // In RGB mode we progress blinking mode only at the end of cycle of just one color
                    // in other modes we always progress
                    progressBlinkingMode(p_rgb_led_descriptor);
                }
            }
        }
    }

    taskEXIT_CRITICAL_FROM_ISR(uxSavedInterruptStatus);
}

//=== LED 0 ===
static void vBlue0TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != BTIMER_ID)
    {
        xil_printf("Blue 0 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led0, &rgb_led0.leds[BLUE_MODE], TRUE);
    xTimerStart(rgb_led0.leds[BLUE_MODE].xTimer, 0);
}

static void vGreen0TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != GTIMER_ID)
    {
        xil_printf("Green 0 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led0, &rgb_led0.leds[GREEN_MODE], FALSE);
    xTimerStart(rgb_led0.leds[GREEN_MODE].xTimer, 0);
}

static void vRed0TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != RTIMER_ID)
    {
        xil_printf("Red 0 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led0, &rgb_led0.leds[RED_MODE], FALSE);
    xTimerStart(rgb_led0.leds[RED_MODE].xTimer, 0);
}

//=== LED 1 ===
static void vBlue1TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != BTIMER_ID)
    {
        xil_printf("Blue 1 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led1, &rgb_led1.leds[BLUE_MODE], TRUE);
    xTimerStart(rgb_led1.leds[BLUE_MODE].xTimer, 0);
}

static void vGreen1TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != GTIMER_ID)
    {
        xil_printf("Green 1 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led1, &rgb_led1.leds[GREEN_MODE], FALSE);
    xTimerStart(rgb_led1.leds[GREEN_MODE].xTimer, 0);
}

static void vRed1TimerCallback(TimerHandle_t pxTimer)
{
    long lTimerId;
    configASSERT(pxTimer);
    lTimerId = (long)pvTimerGetTimerID(pxTimer);
    if (lTimerId != RTIMER_ID)
    {
        xil_printf("Red 1 Timer failed\r\n");
    }
    vUpdateDutyCycle(&rgb_led1, &rgb_led1.leds[RED_MODE], FALSE);
    xTimerStart(rgb_led1.leds[RED_MODE].xTimer, 0);
}
